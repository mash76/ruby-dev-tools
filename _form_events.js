	// jqueryにセットする用にエスケープ id="val[1]" の項目を選択するときなど
	function escapeJquerySelector(val){
		return val.replace(/[ !"#$%&'()*+,.\/:;<=>?@\[\\\]^`{|}~]/g, "\\$&");
	}

	// 項目に値をセットしてform submit
	function setVal(key,val,is_submit = "submit"){
    $('#' + escapeJquerySelector(key)).val(val)
    if (is_submit == "submit" ) $('#f1').submit()
  }

  // 動画管理でのファイルカウント
	function movieOpenAndCountUp(inode){
    console.log(inode)
		let url = '?movie_open_inode=' + inode
    console.log(url)
		$.get(url).done( (data) => { console.log(data) } )
	}

	// ファイルをopen
	function openFile(path){
    console.log(path)
		let url = '?os_open=' + encodeURIComponent(path)
		$.get(url).done( (data) => { console.log(data) } )
	}

	function openWithOpenEmu(path){
		let url = '?openemu=' + encodeURIComponent(path)
		$.get(url).done( (data) => { console.log(data) } )
	}

	function openWithHandbrake(path){
		let url = '?openhandbrake=' + encodeURIComponent(path)
		$.get(url).done( (data) => { console.log(data) } )
	}

	// finder選択
	function setFinderSelect(path){
		let url = '?finderselect=' + encodeURIComponent(path)
		$.get(url).done( (data) => { console.log(data) } )
	}

  function colorUsedTextBox(){
    $("input:text").each( (i,e) =>{
      if ($(e).val() != ""){
        $(e).css("background","#eef").css("border","2px solid #88f")
      }
    })
    $("textarea").each( (i,e) =>{
      if ($(e).val() != ""){
        $(e).css("background","#eef").css("border","2px solid #88f")
      }
    })

  }

  $(document).ready(() => {

    $("table.t_hover tr")
    .mouseover( (e) => {
      $(e.target).closest('tr').css('background','#f9f9ff')
    })
    .mouseout( (e) => {
      $(e.target).closest('tr').css('background','')
    })

	  // ダブルクリックで値クリア
    $("form input").dblclick( (e) => {
        $(e.target).val("")
        $('#f1').submit()
    })

    // エスケープ
    $("form input").keyup( (e) => { colorUsedTextBox() })
	  // escape でinputを全部クリア
    $(document).keydown( (e) => {
      if (e.which == 27) {
        $('input').val("")
        $('#f1').submit()
      }
    })

    $('#filter').focus() // 初期フォーカス
    colorUsedTextBox() // 埋まったboxを青に

  })