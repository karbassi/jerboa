# Security Policy

## Reporting a Vulnerability

If you find a security vulnerability in Jerboa, please report it responsibly.

**Do not open a public issue.** Instead, use [GitHub's private vulnerability reporting](https://github.com/karbassi/jerboa/security/advisories/new) to submit:

- Description of the vulnerability
- Steps to reproduce
- Potential impact

## Scope

Jerboa runs in an App Sandbox with read-only file access. Relevant concerns include:

- JavaScript injection via crafted Markdown files
- File system access outside the sandbox
- URL scheme handling vulnerabilities
