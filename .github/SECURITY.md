# Security Policy

## Reporting a Vulnerability

If you find a security vulnerability in Jerboa, please report it responsibly.

**Do not open a public issue.** Instead, email [github@karbassi.com](mailto:github@karbassi.com) with:

- Description of the vulnerability
- Steps to reproduce
- Potential impact

You should receive a response within 48 hours.

## Scope

Jerboa runs in an App Sandbox with read-only file access. Relevant concerns include:

- JavaScript injection via crafted Markdown files
- File system access outside the sandbox
- URL scheme handling vulnerabilities
