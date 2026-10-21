# Asternic Call Center Stats Lite

## Overview

Asternic Call Center Stats Lite is an open-source queue reporting solution for Asterisk© PBX. It provides detailed call center statistics and reporting capabilities for organizations using Asterisk telephony systems.

## Requirements

- Linux server
- MySQL or MariaDB database
- PHP 5.4 or higher
- Web server (Apache recommended)
- Asterisk PBX with queue support

Compatible with:
- Standard LAMP stack
- FreePBX distribution
- Issabel platform

## Security Warning

**Important**: This application exposes call activity data without built-in authentication. It is recommended to:
- Implement HTTP Basic Authentication
- Use .htaccess protection
- Secure web access if the server is publicly accessible

For enhanced security, consider Asternic Call Center Stats PRO.

## Installation

The repository includes an Issabel-aware installer. It reads the MySQL root
password from `/etc/issabel.conf`, creates and configures the `qstatslite`
database, installs the web application and parser, configures the Asterisk
Manager user, registers the Issabel menu item, and adds the five-minute log
parser cron job.

```bash
cd /usr/src
git clone https://github.com/voipiran/asternic-stats-lite.git
cd asternic-stats-lite
chmod 755 install.sh
./install.sh
```

The report is available at:

```text
https://<issabel-host>/queue-stats/
```

The report filter uses the same Jalali datepicker used by VOIZ/Issabel. Dates
are shown in the Persian calendar, converted to Gregorian only when querying
the existing database timestamps, and displayed back in Jalali in the report
headers, PDF cover pages, and daily distribution table. The `queue_log`
parser remains Gregorian internally so existing Asterisk data is not changed.

The installer uses the following Asterisk Manager credentials for the
Asternic realtime views:

```text
User: phpconfig
Secret: php[onfig
```

It adds the account to `manager_custom.conf` when it is not already present
and reloads Asterisk. Existing account definitions are preserved.

## Manual Configuration

If the automatic installer reports a warning, review
`/var/log/asternic-stats-lite-install.log` and verify:

- `/var/www/html/queue-stats/config.php`
- `/usr/local/parseloglite/config.php`
- `/etc/asterisk/manager_custom.conf`
- `crontab -l`

The parser command installed by the script is:

```text
*/5 * * * * php -q /usr/local/parseloglite/parselog.php convertlocal
```

## Accessing Reports

Access your call center statistics by navigating to:
`http://[your-server-ip]/queue-stats`

## Troubleshooting

- Verify Asterisk Manager settings in `/etc/asterisk/manager.conf`
- Ensure MySQL credentials are correct
- Check file permissions
- Validate log file locations

## License

GPL-3.0 license

## Support

For advanced features and professional support, consider Asternic Call Center Stats PRO.
