p = $params

out html_header("cache")
out menu(__FILE__)

# ----------------------------------------
out `ls cache/* -R`.nl2br