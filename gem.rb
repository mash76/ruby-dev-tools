p = $params

out html_header("gem")
out menu(__FILE__)

# ----------------------------------------
filter = p[:filter].to_s
inspect = p[:inspect].to_s
view = p[:view] || 'list'

cache_path = 'cache/gem_specs.json'
chash_gem = Concurrent::Hash.new

# ナビ
['list','env' ,'which','ruby'].each do | view_name |
    out a_tag(same_red(view_name,view) ,'/dev/gem?view=' + view_name) + spc
end



out br

#
if view == 'env'
    out '<pre>' + `gem env` + '</pre>'
end

if view == 'ruby'
    out '<pre>' + `ruby -v` + '</pre>'
end

if view == 'which'
    ctt = 0
    Gem::Specification.each do |spec|
        ctt += 1
        # next if ctt > 11 # 10までならok

        out spc + sBlue('spec ' + spec.name) + spc + spec.inspect + br if inspect.length > 0

        gem_w = run_shell("gem which #{spec.name}").strip

        # ERROR と /lib/あり、なしに分かれる。libなしは1ファイル
        out br + ctt.to_s + sOrange(gem_w) + spc
        if gem_w.include?("ERROR")
            out sRed("ERR")
        else
            out br
            dir = gem_w.gsub('.rb','')
            # ファイル数
            file_ct = `find #{dir}* -type f | wc -l`
            #out file_ct + ' files ' + br
            files = run_shell("find #{dir}* -type f | sort").strip.split_nl
            out br

            lines = 0
            chars = 0
            out2 = ''
            out_hashes = []
            files.map do |line|

                # rbファイルのほかにpngもある
                #out2 << line + spc

                if line.include?('.rb') || line.include?('.conf')
                    file_str = File.read(line)
                    chars += file_str.length
                    lines += file_str.split_nl.length
                    out_hashes << {'file' => line, 'lines' => file_str.split_nl.length, 'chars' => file_str.length }
                    #out2 << (file_str.split_nl.length.to_s + sSilver(' lines ') + file_str.length.to_s + sSilver(' chars ') + br)
                else
                    out_hashes << {'file' => sBG(line), 'lines' => 0, 'chars' => 0 }
                    #out2 << (sRed(' not rb') + br)
                end
            end
            out file_ct + sSilver(' files ') + lines.to_s + sSilver(' lines ') + chars.to_s + sSilver(' chars ') + br
            out out2
            out hash2html(out_hashes)
        end
        out br
    end
end

# list
if view == 'list'
    gems_str = run_shell 'gem list'
    out '<form id="f1" method="post" action="?">'
    out i_text 'filter',filter
    out i_checkbox 'inspect',inspect
    out i_submit_trans '更新'
    out '</form>'

    start = Time.now
    cache_path = 'cache/gem.json'
    if File.exist?(cache_path)
        gem_json_str = File.read(cache_path)
        cache_hash = JSON.parse(gem_json_str)
        out sOrangeBG('cache') + spc +  sSilver(cache_path) + br
    else
        cache_hash = {}
    end

    # 全件リストに
    gems = []
    threads = []
    slp = 0.0
    Gem::Specification.each do |spec|
        out sBlue('spec ' + spec.name) + spc + spec.inspect + br if inspect.length > 0

        downloads = 0
        version_created_at = ''
        if cache_hash.key?(spec.name)
            json1 = JSON.parse(cache_hash[spec.name])
            downloads = json1['downloads'].to_i
            version_created_at = date_str_to_jp_date(json1['version_created_at'])
        end

        gems << {
            'name' => spec.name,
            'version' => spec.version.to_s,
            'url' => a_tag( 'URL', spec.homepage),
            'json' => a_tag('JSON', "https://rubygems.org/api/v1/gems/#{spec.name}.json"),
            'downloads' => (downloads /10000).to_s + sSilver('万'),
            'latest' => version_created_at,

            'summary'=> spec.summary.trim(60),
            'authors' => spec.authors.join(spc) ,
            'gem_dir' => spec.gem_dir
        }

    end

    # 絞り込み
    if filter.length > 0
        gems_select = gems.select do |row|
            (row['name'] + row['summary'] + row['authors']).downcase.include?(filter.downcase)
        end

        gems_select = gems_select.each do |row|
            pattern = Regexp.new('(' + Regexp.escape(filter) + ')',Regexp::IGNORECASE)
            row['name'] = row['name'].gsub(pattern,sRed('\1'))
            row['summary'] = row['summary'].gsub(pattern,sRed('\1'))
            row['authors'] = row['authors'].gsub(pattern,sRed('\1'))
        end
    else
        gems_select = gems
    end
    out sSilver('filtered ') + gems_select.length.to_s + br
    out hash2html(gems_select)

    if cache_hash == {}
        gems_str.split_nl.each do |line|
            slp += 0.1
            threads << Thread.new(slp) do |p_slp|
                #out p_slp.round(2).to_s + spc
                sleep(p_slp)
                gem_name = line.gsub(/\(.*?\)/,'').strip
                json_url = URI("https://rubygems.org/api/v1/gems/#{gem_name}.json")
                response = Net::HTTP.get(json_url)
                res = response.encode("UTF-8",invalid: :replace, undef: :replace, replace: '?')
                res_hash = JSON.parse(res)
                chash_gem[gem_name] = response
            end #thread
        end
        threads.each(&:join)
        File.open(cache_path, 'w') do |file|
            file.puts( chash_gem.to_json)
        end
    end

    el_times = Time.now - start
    out el_times.round(2).to_s + br
end