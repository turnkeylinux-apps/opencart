OpenCart - open source online e-commerce solution.
=======================================================

`OpenCart`_ is an easy to-use, powerful, Open Source online
store management program that can manage multiple online
stores from a single back-end. Administrative area simply 
by filling in forms and clicking "Save".

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- OpenCart configurations:

  - Installed from upstream source zip file to /var/www/opencart and
    /var/www/opencart-storage.

  - Admin page located at https://YOUR_SERVER/turnkey_admin

    **Security note**: Updates to OpenCart may require supervision so
    they **ARE NOT** configured to install automatically. See the `OpenCart
    docs`_ for info on updating OpenCart.
  
- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email from web
  applications (e.g., password recovery)
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  OpenCart: username **admin**

.. _OpenCart: https://www.opencart.com/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
.. _OpenCart docs: https://docs.opencart.com/en-gb/upgrading/
