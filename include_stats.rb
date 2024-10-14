p = $params
conns = $mysql_conns

out html_header("include_stats")
out menu(__FILE__)
# ----------------------------------------

# includeファイルの関数がそれぞれ何度使われているか統計
out sBlue("関数の利用回数 ")

# 関数一覧
lines = File.read("_include.rb").split_nl
lines = lines.select { | line | line.match(/def /)}
out lines.length.to_s + br
funcs = []
shell = "ls " + Dir.pwd + "/*.rb | grep -v _include.rb"
lines.each do |line|
    func_name = line.gsub(/(\s*?def ?)/,"").gsub(/[\(|\s]+.*/,"")
    shell2 = shell + " | xargs grep " + func_name
    ret = run_shell(shell2,NO_DISP)
    funcs << { func_name: func_name, used: ret.split_nl.length }
end

funcs = funcs.sort { |a, b| b[:used] <=> a[:used] }

out hash2html(funcs)