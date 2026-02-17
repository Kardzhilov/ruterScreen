# Security Policy

## Overview

This document describes the security improvements made to the RuterScreen project and provides guidance on reporting security vulnerabilities.

## Security Fixes Implemented

### Critical Vulnerabilities Fixed

#### 1. Shell Injection via Unquoted Variables (CVE-SEVERITY: CRITICAL)

**Issue**: User-controlled input was used directly in `sed` commands without proper escaping, allowing for potential shell injection attacks.

**Files Affected**:
- `setup.sh`
- `scripts/launchSite-template.sh`
- `scripts/update_weather.sh`

**Fix**: 
- Implemented `safe_replace_config()` function that uses `awk` for safer config file updates
- Added proper escaping for all user inputs using `printf` and `sed` escaping
- Replaced direct `sed` usage with `perl` for HTML template replacements with proper escaping

**Impact**: Prevented Remote Code Execution (RCE) through malicious input in URLs and configuration values.

#### 2. Unsafe Process Termination (CVE-SEVERITY: HIGH)

**Issue**: Using `pkill` and `killall` commands without PID validation could be exploited for process hijacking or unintended process termination.

**Files Affected**:
- `scripts/launchSite-template.sh`

**Fix**:
- Replaced `pkill -9 firefox-esr` and `killall -9 firefox-esr` with PID-based termination
- Use `pgrep -x` to get specific PIDs
- Kill processes individually with explicit PIDs: `kill -15 $pid` then `kill -9 $pid` if needed

**Impact**: Prevented unauthorized process termination and improved reliability.

#### 3. Insecure Temporary Directory Creation (CVE-SEVERITY: MEDIUM-HIGH)

**Issue**: Temporary Firefox profile directory was created with default permissions, allowing other users to access profile data.

**Files Affected**:
- `scripts/launchSite-template.sh`

**Fix**:
- Changed `mktemp -d` to `mktemp -d -m 0700` to create directories with restricted permissions
- Only the owner can read, write, or execute

**Impact**: Prevented information disclosure of Firefox profile data, cookies, and cache.

### Input Validation Improvements

#### 4. Weather Location ID Validation

**Added**:
- `validate_weather_location_id()` function that enforces `wl[0-9]+` format
- Input validation in all scripts that accept weather location IDs

**Impact**: Prevents injection attacks through weather location ID configuration.

#### 5. URL Validation

**Added**:
- `validate_url()` function that ensures URLs start with `http://` or `https://`
- Validation for all Ruter URL inputs

**Impact**: Prevents malformed URLs and potential injection through URL parameters.

#### 6. Numeric Value Validation

**Added**:
- Brightness value validation (0-255 range)
- Timeout value validation (positive integers only)

**Impact**: Prevents unexpected behavior and potential integer overflow issues.

### Python Security Improvements

#### 7. Deprecated Function Removal

**Issue**: `os.getlogin()` is deprecated and can fail in systemd/container environments.

**Files Affected**:
- `scripts/motion_brightness_template.py`

**Fix**:
- Replaced with `os.environ.get('USER', os.environ.get('USERNAME', 'unknown'))`

**Impact**: Improved reliability and compatibility across different execution environments.

### Supply Chain Security

#### 8. File Integrity Verification

**Issue**: Downloaded files were not verified for integrity, allowing potential man-in-the-middle attacks.

**Files Affected**:
- `scripts/dependencies.sh`

**Fix**:
- Added SHA256 checksum verification for downloaded Brightness.zip
- Added placeholder for checksum that should be updated with legitimate value
- Script fails if checksum doesn't match (when not using placeholder)

**Impact**: Protects against supply chain attacks and corrupted downloads.

### Crontab Safety Improvements

#### 9. Safe Crontab Manipulation

**Issue**: Crontab modifications could result in data loss if operations failed.

**Files Affected**:
- `scripts/cronJobs.sh`

**Fix**:
- Added crontab backup before modifications
- Improved grep operations to handle empty crontabs safely
- Added null checks before piping to crontab

**Impact**: Prevents loss of user's existing cron jobs.

### Web Security Enhancements

#### 10. Content Security Policy (CSP)

**Added**:
- CSP headers to all HTML files
- Restricted script sources to `'self'` and necessary external sources (weatherwidget.org)
- Restricted frame sources to known good domains (mon.ruter.no, tavla.entur.no)
- Restricted image sources appropriately

**Impact**: Prevents XSS attacks and unauthorized resource loading.

#### 11. Iframe Sandbox Restrictions

**Improved**:
- Removed `allow-popups` from iframe sandbox attributes
- Restricted to only `allow-scripts allow-same-origin`

**Impact**: Reduced attack surface for embedded content.

## Security Best Practices for Contributors

### When Adding User Input

1. **Always validate input format** before using it
2. **Use parameterized functions** instead of string interpolation
3. **Escape special characters** when necessary
4. **Use appropriate quotes** around variables in shell scripts

### When Modifying Scripts

1. **Avoid using `eval`** or similar dynamic code execution
2. **Use full paths** for commands when possible
3. **Check return codes** of critical operations
4. **Handle errors gracefully**

### When Adding Dependencies

1. **Verify checksums** for all downloaded files
2. **Use HTTPS** for all downloads
3. **Pin versions** when possible
4. **Review source code** of dependencies

## Reporting a Vulnerability

If you discover a security vulnerability in RuterScreen, please report it by:

1. **DO NOT** create a public GitHub issue
2. Contact the maintainer directly via GitHub's private vulnerability reporting
3. Provide detailed information about the vulnerability:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Fix Development**: Varies by severity
- **Public Disclosure**: After fix is released and users have time to update

## Security Update Policy

Security updates will be:
- Released as soon as possible after verification
- Clearly marked in release notes
- Documented in this SECURITY.md file

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | ✅ Yes             |
| Older   | ❌ No              |

Users are encouraged to always use the latest version for the best security posture.

## Additional Security Recommendations

### For End Users

1. **Keep your system updated**: Regularly update Raspberry Pi OS and all packages
2. **Use strong passwords**: If your Pi is network-accessible
3. **Restrict network access**: Use firewall rules to limit exposure
4. **Review configurations**: Before running setup scripts, review what they do
5. **Monitor logs**: Check `/tmp/firefox_launch.log` and motion detector logs

### For Deployment

1. **Run on dedicated device**: Don't expose other services on the same Pi
2. **Use separate user account**: Don't run as root
3. **Backup configurations**: Keep copies of your launchSite.sh configuration
4. **Test in safe environment**: Test updates before applying to production

## Security Contact

For security-related questions or concerns, please open a discussion on GitHub or contact the maintainer.

---

Last Updated: 2024
