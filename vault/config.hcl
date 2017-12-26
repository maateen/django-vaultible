vault {
  grace = "1m"
  #unwrap_token = true
  renew_token = true
}

template {
  source = "mysite/settings.py.ctmpl"
  destination = "mysite/settings.py"
  create_dest_dirs = true
  #command = "restart service foo"
  #command_timeout = "60s"
  error_on_missing_key = false
  perms = 0600
  left_delimiter  = "{{"
  right_delimiter = "}}"

  wait {
    min = "2s"
    max = "10s"
  }
}