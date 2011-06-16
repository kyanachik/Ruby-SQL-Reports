SQLREPORTS_CONFIG = YAML.load_file("#{RAILS_ROOT}/config/sqlreports.yml")[RAILS_ENV]
SQLREPORTS_REPORTS = YAML.load_file("#{RAILS_ROOT}/config/sqlreports.yml")['reports']

