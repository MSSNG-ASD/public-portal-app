# Setup to run locally

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version
* System dependencies
* Configuration
* Database creation
* Database initialization
* How to run the test suite
* Services (job queues, cache servers, search engines, etc.)
* Deployment instructions

## How to set up

### 1. Install xcode CLI tools (if you don't have it)
`xcode-select --install`

### 2. Install homebrew (if you don't have it)
`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

### 3. Install git (if you don't have it)
`brew install git`

### 4. Configure git (if you haven't done it)
`git config -l --global`

### 5. Install gpg (if you don't have it)
`brew install gpg`

### 6. Install rvm (if you don't have it)
- https://rvm.io/rvm/install
- `gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB`
- `\curl -sSL https://get.rvm.io | bash -s stable`

### 7. Install desired ruby, create autism gemset
- `rvm install 2.4.3`
- `rvm use 2.4.3`
- `rvm gemset create autism`
- `rvm gemset use autism`

### 8. Clone this git repo
- `git clone <url to this repo>`

### 9. Install code dependencies
- `gem install bundler`
- `bundle install`

### 10. Set your environment variables

You will have to set/export your environment variables as specified in `.env.dist`.

### 11. Ensure that your DB is up and running.

### 12. Build development databases
```bash
RAILS_ENV=development bundle exec rake db:create
RAILS_ENV=development bundle exec rake db:migrate
```

### 13. Build entrez database
- Create entrez database
  ```
  echo "create database entrez_gene_20180612;" | mysql -uroot -p<your_db_password>
  ```
- Download db dump
  ```
  gsutil cp gs://entrez/entrez_gene_20180612.sql.gz .
  ```
- Load db dump
  ```
  zcat entrez_gene_20180612.sql.gz | mysql -uroot -p<your_db_password> entrez_gene_20180612
  ```

If you encounter the error `ERROR 2006 (HY000) at line 87: MySQL server has gone away` during the
import above, execute these commands in MySQL as root:

```sql
set global net_buffer_length=1000000;
set global max_allowed_packet=1000000000;
```

### 14. Run local server
`rails server`