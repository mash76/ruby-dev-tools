p = params = $params

out html_header("grep")
out '<script>' + File.read("_form_events.js") + '</script>'
out menu(__FILE__)
# ----------------------------------------

home = `echo $HOME`.strip
path = home + "/react"

files_str = run_shell 'find "' + path + '" -type f '
files = files_str.split_nl
out br

filter = params[:filter].to_s

out '<form id="f1" method="post" action="?">'
out i_text "filter",filter
out i_submit_trans "検索"
out "</form><hr/>"

file_filtered = files.select { |line| line.include?(filter) }

out file_filtered.length.to_s + br
pattern = Regexp.new("(" + Regexp.escape(filter) + ")",Regexp::IGNORECASE)
file_filtered.each do |line|
    out line.gsub(home,"").gsub(pattern,sRed('\1')) + br
end
