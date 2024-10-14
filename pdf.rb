PDF_PATH = File.expand_path '../../scan'

p = $params

out html_header("pdf")
out '<script>' + File.read("_form_events.js") + '</script>'
out menu(__FILE__)

# ----------------------------------------

pdfs = run_shell "find " + PDF_PATH
out br
out pdfs.nl2br.gsub(PDF_PATH,"")
