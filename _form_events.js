	// jqueryにセットする用にエスケープ id="val[1]" の項目を選択するときなど
	function escapeJquerySelector(val){
		return val.replace(/[ !"#$%&'()*+,.\/:;<=>?@\[\\\]^`{|}~]/g, "\\$&");
	}

	// 項目に値をセットしてform submit
	function setVal(key,val,is_submit = "submit"){
    $('#' + escapeJquerySelector(key)).val(val)
    if (is_submit == "submit" ) $('#f1').submit()
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

  function eventCommonInputs(){

    // inputタグ系イベント整え
    $("table.t_hover tr")
    .mouseover( (e) => {
      $(e.target).closest('tr').css('background','#f9f9ff')
    })
    .mouseout( (e) => {
      $(e.target).closest('tr').css('background','')
    })

	  // textダブルクリックで値クリア
    $("form input").dblclick( (e) => {
        $(e.target).val("")
        $('#f1').submit()
    })

    // ESCで全フォームクリア
    $("form input").keyup( (e) => { colorUsedTextBox() })
	  // escape でinputを全部クリア
    $(document).keydown( (e) => {
      if (e.which == 27) {
        $('input').val("")
        $('#f1').submit()
      }
    })


  }

  // debug_logのdivをダブルクリックで消す
  function eventCommonDebugs(){

    $('div#debug_log').dblclick(()=>{
      $('div#debug_log').hide()
    })
  }


  $(document).ready(() => {
    eventCommonInputs()
    eventCommonDebugs()
    $('#filter').focus() // 初期フォーカス
    colorUsedTextBox() // 埋まったboxを青に
  })

  // 個別画面

  // 動画管理  ファイルカウント
	function movieOpenAndCountUp(inode){
    console.log(inode)
		let url = '?movie_open_inode=' + inode
    console.log(url)
		$.get(url).done( (data) => { console.log(data) } )
	}
