#!/usr/bin/python3
"""Set OpenCart admin password, email and domain to serve

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT="www.example.com"
"""

import sys
import getopt
from libinithooks import inithooks_cache

from libinithooks.dialog_wrapper import Dialog
from mysqlconf import MySQL
import subprocess


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)


DEFAULT_DOMAIN = "www.example.com"


def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email=', 'domain='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    email = ""
    domain = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val
        elif opt == '--domain':
            domain = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')

        password = d.get_password(
            "OpenCart Password",
            "Enter new password for the OpenCart 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "OpenCart Email",
            "Enter email address for the OpenCart 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    if not domain:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')
        domain = d.get_input(
                "OpenCart domain",
                "Enter domain to serve OpenCart",
                DEFAULT_DOMAIN)

    if domain == "DEFAULT":
        domain = DEFAULT_DOMAIN

    inithooks_cache.write('APP_DOMAIN', domain)
    
    subprocess.run(["sed", "-ri",
        "s|('HTTP(S?)_SERVER',) '.*'|\\1 'https\\L\\2://%s/'|g" % domain,
        "/var/www/opencart/config.php"], check=True)
    subprocess.run(["sed", "-ri",
        "s|('HTTP(S?)_SERVER',) '.*'|\\1 'https\\L\\2://%s/turnkey_admin/'|g" % domain, 
        "/var/www/opencart/turnkey_admin/config.php"], check=True)
    subprocess.run(["sed", "-ri",
        "s|('HTTP(S?)_CATALOG',) '.*'|\\1 'https\\L\\2://%s/'|g" % domain,
        "/var/www/opencart/turnkey_admin/config.php"], check=True)

    apache_conf = "/etc/apache2/sites-available/opencart.conf"
    subprocess.run(["sed", "-i", "\|RewriteRule|s|https://.*|https://%s/\$1 [R,L]|" % domain, apache_conf], check=True)
    subprocess.run(["sed", "-i", "\|RewriteCond|s|!^.*|!^%s$|" % domain, apache_conf], check=True)
    subprocess.run(["service", "apache2", "restart"], check=True)

    password_hash = subprocess.run(
        ["php", "-r", "echo password_hash(stream_get_contents(STDIN), PASSWORD_DEFAULT);"],
        input=password,
        text=True,
        check=True,
        capture_output=True,
    ).stdout

    m = MySQL()
    m.execute('UPDATE opencart.oc_user SET email=%s WHERE username="admin"', (email,))
    m.execute('UPDATE opencart.oc_user SET password=%s WHERE username="admin"', (password_hash,))

if __name__ == "__main__":
    main()
