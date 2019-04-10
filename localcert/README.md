# Local development with production-like error handling

The normal Rails development configuration handles errors differently than production: at development time, you get a
detailed error message with a stack trace; at production time, you get an opaque error page.

Here is how to set things up so you can see production-like error responses locally:

1. Add the following near the bottom of `config/environments/development.rb`:
    ```ruby
      config.consider_all_requests_local = false
    
      OmniAuth.config.full_host = lambda do |env|
        "https://mssng-dev.dnastack.com"
      end
    ```
2. Add the following line to your `/etc/hosts` file:
   ```
   127.0.0.1 mssng-dev.dnastack.com
   ```
3. Run an NGINX reverse proxy locally:
   ```
   $ cd localcert
   $ sudo nginx -c $(pwd)/nginx.conf
   ```
4. Go to [https://mssng-dev.dnastack.com] in your browser. You will need to accept the self-signed certificate.
5. Cause errors and see the same error pages you would see in production!
