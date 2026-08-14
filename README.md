# Connection-Tester
A simple PowerShell script for monitoring local router and Internet connectivity.

The script periodically checks:
- connectivity to the default gateway
- connectivity to an external host
- router response time
- Internet response time

The last measurements are displayed in the console, while connection problems and high response times are saved to daily CSV log files.
