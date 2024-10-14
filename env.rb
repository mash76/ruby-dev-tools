p = $params

out html_header("env")
out '<script>' + File.read("_form_events.js") + '</script>'
out menu(__FILE__)
# ----------------------------------------

envs = run_shell("env")
out br + envs.nl2br
