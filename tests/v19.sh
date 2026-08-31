#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://localhost
admin_base=$base/turnkey_admin
cookie=/tmp/tkl-opencart-cookie.$$
page=/tmp/tkl-opencart-page.$$
response=/tmp/tkl-opencart-response.$$

cleanup() {
    rm -f -- "$cookie" "$page" "$response"
}
trap cleanup EXIT
trap 'status=$?; echo "OpenCart acceptance failed at line $LINENO (status $status)" >&2; exit "$status"' ERR

systemctl --quiet is-active apache2.service mariadb.service postfix.service cron.service
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service cron.service
apache2ctl -t
test "$(sed -n "s/^define('VERSION', '\([^']*\)').*/\1/p" /var/www/opencart/index.php)" = 4.1.0.4

curl --insecure --fail --silent --show-error --location \
    --cookie "$cookie" --cookie-jar "$cookie" \
    "$admin_base/" >"$page"
grep -Fq 'id="form-login"' "$page"
login_url=$(sed -n 's/.*<form id="form-login" action="\([^"]*\)".*/\1/p' "$page" |
    sed 's/&amp;/\&/g' | head -n1)
test -n "$login_url"
curl --insecure --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode 'username=admin' \
    --data-urlencode "password=$app_password" \
    "$login_url" >"$response"
dashboard_url=$(python3 -c 'import html,json,sys; print(html.unescape(json.load(open(sys.argv[1]))["redirect"]))' "$response")
curl --insecure --fail --silent --show-error --location \
    --cookie "$cookie" --cookie-jar "$cookie" \
    "$dashboard_url" >"$page"
grep -Fq 'common/logout' "$page"
grep -Fq 'Dashboard' "$page"
user_token=$(sed -n 's/.*[?&]user_token=\([^&]*\).*/\1/p' <<<"$dashboard_url")
test -n "$user_token"

language_id=$(mariadb --batch --skip-column-names opencart --execute \
    "SELECT language_id FROM oc_language WHERE code='en-gb'")
[[ $language_id =~ ^[0-9]+$ ]]
save_url="$admin_base/index.php?route=catalog/product.save&user_token=$user_token"
curl --insecure --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode "product_description[$language_id][name]=TurnKey v19 acceptance product" \
    --data-urlencode "product_description[$language_id][description]=Created by the focused v19 appliance acceptance" \
    --data-urlencode "product_description[$language_id][meta_title]=TurnKey v19 acceptance product" \
    --data-urlencode "product_description[$language_id][meta_description]=OpenCart appliance acceptance product" \
    --data-urlencode "product_description[$language_id][meta_keyword]=turnkey-v19" \
    --data-urlencode "product_description[$language_id][tag]=turnkey-v19" \
    --data-urlencode 'model=TKL19-ACCEPT' \
    --data-urlencode 'location=' \
    --data-urlencode 'quantity=5' \
    --data-urlencode 'minimum=1' \
    --data-urlencode 'subtract=0' \
    --data-urlencode 'stock_status_id=5' \
    --data-urlencode "date_available=$(date +%F)" \
    --data-urlencode 'manufacturer_id=0' \
    --data-urlencode 'shipping=0' \
    --data-urlencode 'price=19.00' \
    --data-urlencode 'points=0' \
    --data-urlencode 'weight=0' \
    --data-urlencode 'weight_class_id=1' \
    --data-urlencode 'length=0' \
    --data-urlencode 'width=0' \
    --data-urlencode 'height=0' \
    --data-urlencode 'length_class_id=1' \
    --data-urlencode 'status=1' \
    --data-urlencode 'tax_class_id=0' \
    --data-urlencode 'sort_order=0' \
    --data-urlencode 'image=' \
    --data-urlencode 'product_store[]=0' \
    --data-urlencode "product_seo_url[0][$language_id]=turnkey-v19-acceptance-product" \
    "$save_url" >"$response"
product_id=$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert "error" not in data, data; print(data["product_id"])' "$response")
[[ $product_id =~ ^[0-9]+$ ]]
test "$(mariadb --batch --skip-column-names opencart --execute \
    "SELECT COUNT(*) FROM oc_product WHERE product_id=$product_id AND model='TKL19-ACCEPT' AND status=1")" = 1
test "$(mariadb --batch --skip-column-names opencart --execute \
    "SELECT COUNT(*) FROM oc_product_description WHERE product_id=$product_id AND name='TurnKey v19 acceptance product'")" = 1
curl --insecure --fail --silent --show-error \
    "$base/index.php?route=product/product&product_id=$product_id" >"$page"
grep -Fq 'TurnKey v19 acceptance product' "$page"

systemctl restart mariadb.service apache2.service
systemctl --quiet is-active mariadb.service apache2.service
test "$(mariadb --batch --skip-column-names opencart --execute \
    "SELECT COUNT(*) FROM oc_product WHERE product_id=$product_id AND model='TKL19-ACCEPT'")" = 1
curl --insecure --fail --silent --show-error \
    "$base/index.php?route=product/product&product_id=$product_id" >"$page"
grep -Fq 'TurnKey v19 acceptance product' "$page"

password_hash=$(mariadb --batch --skip-column-names opencart --execute \
    "SELECT password FROM oc_user WHERE username='admin'")
[[ $password_hash == '$2y$'* ]]
dpkg-query -W php8.4-cli php8.4-mysql php8.4-gd php8.4-curl \
    php8.4-zip php8.4-mbstring php8.4-xml libapache2-mod-php8.4 \
    mariadb-server webmin-apache webmin-mysql >/dev/null
curl --insecure --fail --silent --show-error --head https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

release_json=$(curl --fail --silent --show-error \
    https://api.github.com/repos/opencart/opencart/releases/tags/4.1.0.4)
grep -Fq '"tag_name": "4.1.0.4"' <<<"$release_json"
grep -Fq 'sha256:cdef537f5a0a7e1b4ddbe16f589dd2e80b10150a09bfbe93ce76ef2d5c3218c0' \
    <<<"$release_json"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie PHP, MariaDB and Apache packages; official OpenCart 4.1.0.4 release archive
installed_version=OpenCart 4.1.0.4; PHP $(php -r 'echo PHP_VERSION;')
runtime_checks=normal init; Apache TLS storefront; firstboot administrator web login and current password hash; authenticated product creation; MariaDB and public storefront readback; restart persistence; Webmin and local Postfix
updater_command=back up the database, storage and configuration; apply a reviewed official release according to OpenCart's supervised upgrade procedure
updater_result=official OpenCart 4.1.0.4 release metadata and asset digest matched the verified build archive
updater_channel=official OpenCart releases and documented supervised upgrade workflow
integrity_evidence=build and runtime verify GitHub's release-asset SHA-256 cdef537f5a0a7e1b4ddbe16f589dd2e80b10150a09bfbe93ce76ef2d5c3218c0; Debian metadata is signed; no Bookworm source remained
EOF
