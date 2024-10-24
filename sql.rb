class Sql
  def main

      p = $params
      conns = $mysql_conns

      out html_header("mysql")
      out menu(__FILE__)
      # ----------------------------------------

      conn_name = p[:conn_name].to_s
      conn_name = "sakila" if conn_name.length == 0
      sql_text = p[:sql_text].to_s

      out sBlue("mysql sql実行") + br
      conns.each do |key,hash|
        out a_tag(same_red(key,conn_name),"?conn_name=" + key)
      end

      out '<form method="get" action="?">'
      out i_hidden "conn_name",conn_name
      out i_textarea "sql_text",sql_text
      out i_submit "実行"
      out "</form><hr/>"

      sqls = sql_text.split(";")

      sqls.each do |sql|
        results = sql2hash(sql,conn_name)
        out hash2html(results)
      end
  end
end