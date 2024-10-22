class Ps
    def main
        p = $params

        out html_header("ps")
        out menu(__FILE__)
        # ----------------------------------------

        filter = p[:filter].to_s

        out sBlueBG("ps")

        out '<form id="f1" method="post" action="?" >'
        out i_text "filter", filter,30
        out i_submit_trans "更新"
        out '</form >'

        shell = " ps aux "
        shell += " | grep " + filter if filter.length > 0
        ps_str = run_shell shell
        ps_hash = ps_str.split_nl
        ps_hash.shift
        hashes = ps_to_hashes(ps_hash)

        # 統計 user
        col_stat = hash_stat_col(hashes,"USER")
        sorted_h = col_stat.sort_by { |key, value| -value }.to_h
        sorted_h = hash2records(sorted_h)
        sorted_h.each do |row|
            row[:key] = a_tag( row[:key], "?filter=" + row[:key] )
        end

        # 一覧に色つける
        hashes.each do |row|
            row = color_row(row ,filter ) if filter.length > 0
        end

        out '<table><tr><td valign=top >'
        out sorted_h.length.to_s
        out hash2html(sorted_h)
        out '</td><td valign=top>'
        out hashes.length.to_s
        out hash2html(hashes)
        out '</td></tr></table>'
    end

    def ps_to_hashes(ps_hash)
        hashes = []
        ps_hash.each do | line |
            f = line.split(/\s+/)
            hashes << {
                "USER" => f[0] ,
                "PID" => f[1] ,
                "%CPU" =>f[2] ,
                "%MEM" =>f[3] ,
                "VSZ" =>f[4] ,
                "RSS" =>f[5] ,
                "TT" =>f[6] ,
                "STAT" =>f[7] ,
                "STARTED" =>f[8] ,
                "TIME" => f[9] ,
                "COMMAND"=> f[10]
            }
        end
        hashes
    end

    def hash_stat_col(hashes,col_name)
        ret = {}
        hashes.each do |row|
            val = row[col_name]
            ret[val] = 0 unless ret.key?(val)
            ret[val] += 1
        end
        ret
    end
end