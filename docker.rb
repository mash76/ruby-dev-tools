


def main

    p = $params

    out html_header("docker")
    out menu(__FILE__)
    # ----------------------------------------

    out br + sBG("docker images ")

    out br + sBG("docker ps ")

    # 全項目 json . 指定項目 json .ID
    shell = "docker ps --format '{{ .ID}}\t{{ .Names}}\t{{ .Image}}\t{{ .State}}\t{{ .Ports}}\t{{ .RunningFor}}\t{{ .CreatedAt}}' "
    containers_str = run_shell(shell)
    lines = containers_str.split_nl
    containers = lines.map { |line | array2hash(line.split_tab,["ID","Names","Image","Satte","Ports","RunningFor","CreatedAt"] )}
    out br + hash2html(containers) + br

    # コンテナ内ファイル
    containers.each do |container_h|

        out sBlueBG(container_h["Names"]) + spc + sBlueBG(container_h["Image"] ) + br
        shell = " docker inspect " + container_h['ID']
        inspect_str = run_shell shell
        #out inspect_str + br
        c_inspect_hash = JSON.parse(inspect_str)
        c_inspect_hash.each do | inspect_h |
            out br
            mount_hashes = fill_hash_cols(inspect_h["Mounts"],["Type","Name","Source","Destination","Mode","RW","Propagation"])
            out hash2html(mount_hashes)

            out sBG("container files") + br
            Dir.chdir(`pwd`.strip + "/docker") do
                mount_hashes.each do |mount_h|
                    shell_ls = "docker-compose exec db find " + mount_h["Destination"]
                    str1 = run_shell(shell_ls,100)
                    out br + str1.nl2br + br
                end
            end

            out sBG("container inspect") + br
            inspect_h.each do |key ,val|
                out sBlue(key) + " : " + val.to_s + br
            end
            out br
        end
    end

    shell = "docker ps --format '{{json .}}'"
    branches_str = run_shell shell
    branches = JSON.parse(branches_str)
    branches = [branches]
    branches.each { | b | b['Labels'] = b['Labels'].trim(30) }
    out br + hash2html(branches)

end



main