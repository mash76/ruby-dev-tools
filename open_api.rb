
def main
    p = $params

    out html_header("open_api")
    out menu(__FILE__)
    # ----------------------------------------


    # ファイル読み込み
    json_file_path = "files/freee-api.json"
    if !File.exist?(json_file_path)
        out "no file " + json_file_path
    end
    json_str = File.read(json_file_path)
    file_size = File.size(json_file_path)
    hash = JSON.parse(json_str)
    #hash = escape_hash(hash)

    out s120(sBlueBG(json_file_path) + spc ) + json_str.split_nl.length.to_s + sSilver(" lines ") + (file_size /1024).to_s + sSilver(" Kb ") + br
    out hash['info']['title'] + br

    # json ダンプ
    #out "<pre style='background:#f8f8f8;'>" + ERB::Util.html_escape(json_str) + "</pre>"

    ref_counts = count_ref_keys(hash) # '$ref'キーの値ごとにカウント
    out sBlue("共通部品") + spc + ref_counts.length.to_s + br
    rec_2over = ref_counts.select { |key, value| 2 <= value && value < 7 }
    rec_7over = ref_counts.select { |key, value| 7 <= value }
    out sBlue("参照7以上一覧") + br
    rec_7over.each do |key,val|
        out sBlue(key) + spc + val.to_s + br
    end
    out "<hr/>"
    # out sBlue("参照2以上一覧") + br
    # rec_2over.each do |key,val|
    #     out sBlue(key) + spc + val.to_s + br
    # end

    # 結局の
    method_stats = Hash.new(0)
    tags = Hash.new(0)
    path_param_stats = {}
    query_param_stats = {}
    #いろいろカウント
    hash["paths"].each do |path,path_hash|
        path_hash.each do |method,h_method|
            method_stats[method] += 1
            h_method["tags"].each { |tag | tags[tag] += 1 }
            if h_method.key?("parameters")
                h_method["parameters"].each do |h_param|
                method_desc = strip_html_tags(h_method['description']).trim(10)
                    h_param["desctiption"] = h_param["desctiption"].trim(15) if h_param.key?("desctiption")
                    if h_param["in"] == "path"
                        path_param_stats[h_param["name"]] = [] unless path_param_stats.key?(h_param["name"])
                        path_param_stats[h_param["name"]] << {"method" => method,"path" => path,"api_desc" => method_desc}.merge!(h_param)
                    end
                    if h_param["in"] == "query"
                        query_param_stats[h_param["name"]] = [] unless query_param_stats.key?(h_param["name"])
                        query_param_stats[h_param["name"]] << {"method" => method,"path" => path,"api_desc" => method_desc}.merge!(h_param)
                    end
                end
            end
        end
    end

    # カウント結果表示
    out method_stats.values.sum.to_s + sSilver(" APIs ") + br

    out sBG("method_stats ")
    method_stats.each do |method,count|
        out a_tag(method,"?method=" + method) + spc + count.to_s + " &nbsp; "
    end
    out br
    out sBG("tags ") + tags.inspect + br
    out sBlueBG("path_param_stats") + spc + path_param_stats.length.to_s + br
    path_param_stats.each { | key,h_param| out '<a href="?stat_param_name=' + key + '">' + sBG(key) + spc + sGray(h_param.length.to_s) + "</a>  &nbsp; "}
    out br + sBlueBG("query_param_stats") + spc + query_param_stats.length.to_s + br
    query_param_stats.each { | key,h_param| out '<a href="?stat_param_name=' + key + '">' + sBG(key) + spc + sGray(h_param.length.to_s) + "</a>  &nbsp; "}
    out br + br


    # パラメータ分析指定あれば(stat_param_name)分析
    if p.key?(:stat_param_name)
        stat_param_name = p[:stat_param_name]
        col_order = ["method","path","api_desc","in","name","required","description","schema","example"]
        if path_param_stats.key?(stat_param_name)
            out sRed(stat_param_name) + spc + path_param_stats[stat_param_name].length.to_s + br
            path_param_stats[stat_param_name].map { |hash| hash['description'] = hash['description'].trim(20) }
            path_param_stats[stat_param_name] = fill_hash_cols(path_param_stats[stat_param_name],col_order) #並び替えと補完
            out hash2html(path_param_stats[stat_param_name])
            # query_param_stats[stat_param_name].each { |h_param| out h_param.inspect + br }
        end
        if query_param_stats.key?(stat_param_name)
            out sRed(stat_param_name) + spc + query_param_stats[stat_param_name].length.to_s + br
            query_param_stats[stat_param_name].map { |hash| hash['description'] = hash['description'].trim(20) }
            query_param_stats[stat_param_name] = fill_hash_cols(query_param_stats[stat_param_name],col_order) #並び替えと補完
            out hash2html(query_param_stats[stat_param_name])
        end
    end


    hash = resolve_refs(hash,hash)

    #表示
    ct = 0
    hash["paths"].each do |key,path_hash|
        path_hash.each do |method,h_method|
            ct += 1

            next if p.key?("method") && p[:method] != method

            out ct.to_s + spc + h_method["tags"].inspect + spc + method + spc + sBlue(key) + spc + h_method["summary"] + spc
            # h_method["responses"].each do |status_code,hash4|
            #     out color_http_status(status_code.to_i) + spc
            # end
            if h_method.key?("parameters")
                h_method["parameters"].each do |h_param|

                    next if h_param['in'] == "path" # queryパラメータのみ取得
                    # 簡易
                    if h_param['required']
                        out sRedBG(h_param['name']) + spc
                    else
                        out sBG(h_param['name']) + spc
                    end

                    # 詳細
                    # out " &nbsp; &nbsp; " # h_param['in'] # in = query / path
                    # out spc + sBG(h_param['name']) + spc + h_param['schema']['type'] + spc + (h_param['required'] ? sRed('必') : "" ) + spc + sSilver(h_param["description"].gsub(/<br.*?>/,"").trim(20)) + br
                end
            end
            out br

            out "<table><tr>"
            h_method["responses"].each do |status_code,h_response|

                #out br + color_http_status(status_code.to_i) + spc + sBG(h_response['description']) + spc
                if h_response.key?("content")

                    h_response['content'].each do |mime,h_schema|
                        out '<td valign="top">'
                        out color_http_status_bold(status_code.to_i) + spc + sSilver(h_response['description']) + br
                        out sOrange(mime) + spc + br
                        width = "600px" if (200 <= status_code.to_i && status_code.to_i < 300)
                        width = "160px" if 300 <= status_code.to_i
                        out '<div style="background:#fafafa; border:1px solid #e9e9e9; padding:3px; font-size:70%; width:' + width.to_s + '; ">'
                        dump_hash("",h_schema["schema"],0)
                        out '</div>'
                        out "</td>"
                    end
                else
                    out '<td valign="top">'
                    width = "600px" if (200 <= status_code.to_i && status_code.to_i < 300)
                    width = "160px" if 300 <= status_code.to_i
                    out color_http_status_bold(status_code.to_i) + spc + sSilver(h_response['description']) + br
                    out '<div style="background:#fafafa; border:1px solid #e9e9e9; padding:3px; font-size:70%; width:' + width.to_s + '; ">'
                    out '</div>'
                    out "</td>"
                end

               # out h_response['content'].inspect + br
            end
            out "</tr></table>"
            out br

        # out sSilver(h_method.inspect) + br
        end
    # break if ct > 6
    end

    # schemas一覧
    ct_schema = 0
    hash["components"]["schemas"].each do |key,hash_schema|
        ct_schema += 1
        out ct_schema.to_s + spc + sRed(key) + br  #spc + hash_schema.inspect + br
    end
    out sBlue("schemas") + spc + hash["schemas"].inspect + br
    #out sBlue("paths") + spc + hash["paths"].inspect + br
    hash.each do |key ,child_hash|
        out sBlue(key) + spc + child_hash.inspect.trim(100) + br
    end
    #out hash.inspect
end

def strip_html_tags(html)
    html.gsub(/<\/?[^>]*>/, "")
  end

def spaces(ct)
    spaces = ""
    ct.times { spaces << "&nbsp; &nbsp;" }
    spaces
end

def dump_hash(key1,hash,depth)
   # out br + spaces(depth) + " depth " + depth.to_s + spc +  hash['type'] + br
    desc = ""
    desc = hash['description'].trim(20) if hash.key?("description")
    if hash['type'] == "object"
        #out spaces(depth) + "{" + br
        out spaces(depth) + sRedBG(key1) + spc + sSilver(desc) + "{" + br
        hash['properties'].each do |key2,hash2|
            dump_hash(key2,hash2,depth + 1)
        end
        out spaces(depth) + "}" + br
    end
    if hash['type'] == "array"
        out spaces(depth) + sRedBG(key1) + spc + hash['type'] + spc + sSilver(desc) + " [" + br
        dump_hash("",hash['items'],depth + 1)
       # out hash['items'].inspect + br
        out spaces(depth) + "]" + br
        return
    end
    if hash['type'] == "integer" || hash['type'] == "string" || hash['type'] == "boolean"
        out spaces(depth) + sBlue(key1) +  spc + hash['type'] + spc + sSilver(desc) + br
        return
    end
    if hash['type'] == "number"
        out spaces(depth) + spc + sBlue(key1) +  " number " + sPink(hash['format']) + spc + sSilver(desc) + br
        return
    end
end

def escape_hash(hash)
    hash.each_with_object({}) do |(key, value), escaped_hash|
      escaped_key = CGI.escapeHTML(key.to_s)

      escaped_value = case value
                      when Hash
                        escape_hash(value)
                      when Array
                        value.map { |v| v.is_a?(String) ? CGI.escapeHTML(v) : v }
                      when String
                        CGI.escapeHTML(value)
                      else
                        value
                      end

      escaped_hash[escaped_key] = escaped_value
    end
end

def color_http_status(code)
      return sBlue(code.to_s) if 200 <= code && code < 300
      return sOrange(code.to_s) if 400 <= code && code < 500
      return sRed(code.to_s) if 500 <= code && code < 600
end

def color_http_status_bold(code)
    return sBlueBG(code.to_s) if 200 <= code && code < 300
    return sOrangeBG(code.to_s) if 400 <= code && code < 500
    return sRedBG(code.to_s) if 500 <= code && code < 600
end

# '$ref'キーの値ごとにカウント
def count_ref_keys(obj, ref_counts = Hash.new(0))
    case obj
    when Array
      obj.each do |item|
        count_ref_keys(item, ref_counts)
      end
    when Hash
      obj.each do |key, value|
        if key.to_s == '$ref'
          ref_counts[value] += 1
        end
        count_ref_keys(value, ref_counts)
      end
    end

    ref_counts
end

# $refを再帰的に解決する関数
def resolve_refs(schema, root_schema)
    if schema.is_a?(Hash)
      if schema.key?('$ref')
        ref = schema['$ref']
        # refのJSONポインタ表記からパスを取得し、特殊文字をエスケープした正しい形式に変換
        ref_path = ref.sub('#/', '').split('/').map { |part| part.gsub('~1', '/') }

        # root_schemaを参照して目的のスキーマにアクセス
        resolved = ref_path.reduce(root_schema) { |subschema, key| subschema[key] }

        # 再帰的に解決したスキーマを返す
        resolve_refs(resolved, root_schema)
      else
        # ハッシュ内の他のキーと値も再帰的に解決する
        schema.transform_values! { |value| resolve_refs(value, root_schema) }
      end
    elsif schema.is_a?(Array)
      # 配列内の要素も再帰的に解決する
      schema.map { |item| resolve_refs(item, root_schema) }
    else
      # ハッシュや配列でない場合はそのまま返す
      schema
    end
end

main