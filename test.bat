@echo off
setlocal
set XDEBUG_MODE=coverage
call php artisan config:clear
call php artisan test --coverage --min=100
exit /b %ERRORLEVEL%