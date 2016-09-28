var intervalID = 0;
var socket = io();

$(document).ready(function () {
    var filterInput;

	$('#tracks li').on('contextmenu', function(e) {
		//prevent default context menu for right click
		e.preventDefault();

		var menu = $(".menu");

		//hide menu if already shown
		menu.hide(); 

		//get x and y values of the click event
		var pageX = e.pageX, pageY = e.pageY;

		//position menu div near mouse cliked area
		menu.css({ top: pageY, left: pageX });

		var mwidth = menu.width();
		var mheight = menu.height();
		var screenWidth = $(window).width();
		var screenHeight = $(window).height();

		//if window is scrolled
		var scrTop = $(window).scrollTop();

		//if the menu is close to right edge of the window
		if(pageX + mwidth > screenWidth) {
		menu.css({ left: pageX - mwidth });
		}

		//if the menu is close to bottom edge of the window
		if(pageY + mheight > screenHeight + scrTop) {
		menu.css({ top: pageY - mheight });
		}

		//finally show the menu
		menu.show();
	}); 

	$("html").on("click", function() {
		$(".menu").hide();
	});

	$(document).on('click', '#restart', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/restart',
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#reload', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/reload',
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#clear', function () {
		$.ajax({
			type: 'POST',
			url: '/backend/clear',
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#logout', function() {
		$.ajax({
			type: 'POST',
			username: 'logout',
			url: '/',
			success: function() {
				window.location.href = '/';
			},
			error: function () {
				window.location.href = '/';
			}
		});
		return false;
	});
	$(document).on('click', '#stop', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/stop',
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#skipleft', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/skipleft',
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#skipright', function () {
		$.ajax({
			type: 'POST',
			url: '/backend/skipright',
			success: function () {
				refresh();
			},
			error: function () {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#tracks li', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/play/' + $(this).attr('data-id').replace(' / ', '/'),
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#playlist li', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/unqueue/' + $(this).attr('data-id').replace(' / ', '/'),
			success: function() {
				refresh();
			},
			error: function() {
				alert('You are not allowed to do that, sorry.');
			}
		});
		return false;
	});
	$(document).on('click', '#shuffle', function() {
		$.ajax({
			type: 'POST',
			url: '/backend/shuffle/',
			success: function() {},
			error: function() {}
		});
		return false;
	});

	var refreshTracks = function() {
		$.ajax({
			cache: false,
			url: '/backend/tracks',
			dataType: 'json',
			success: function(data) {
				$("#tracks").empty();
				data.forEach(function(track, index) {
					if (track.id !== 0) {
						$('<li/>').appendTo('#tracks').attr('data-id', index).text(track);
					}
				});
                $(filterInput).trigger('change');
			}
		});
	};

	var refresh = function() {
		$.ajax({
			cache: false,
			url: '/backend/playlist',
			dataType: 'json',
			success: function (data) {
				$('#playlist').html('');
				data.forEach(function (track, index) {
					$('<li/>').appendTo('#playlist').attr('data-id', index).text(track);
				});
			}
		});
		$.ajax({
			cache: false,
			url: '/backend/playing',
			dataType: 'json',
			success: function(data) {
				if (data) {
					$('#playing').text(data);
				} else {
					$('#playing').text('Not Playing');
				}
			}
		});
	};

	intervalID = setInterval(function() {
		refresh();
	}, 3000);
	refreshTracks();
	refresh();

	$(window).on("blur focus", function(e) {
		var prevType = $(this).data("prevFocusEvent");
		if (prevType != e.type) {
			switch (e.type) {
				case "blur":
					clearInterval(intervalID);
					break;
				case "focus":
					intervalID = setInterval(function() {
						refresh();
					}, 1000);
					break;
			}
		}
		$(this).data("prevFocusEvent", e.type);
	});

	jQuery.expr[':'].Contains = function(a, i, m){
		return (a.textContent || a.innerText || "").toUpperCase().indexOf(m[3].toUpperCase()) >= 0;
	};

	listFilter = function(header, list) {
		// create and add the filter form to the header
		var form = $("<form>").attr({"class": "filterform", "action": "#"}),
			input = $("<input>").attr({"class": "filterinput", "type": "text"});

		$(form).append(input).appendTo(header);

		$(input).change( function() {
			var filter = $(this).val();
			if(filter) {
				$(list).find("li:not(:Contains(" + filter + "))").slideUp();
				$(list).find("li:Contains(" + filter + ")").slideDown();
			} else {
				$(list).find("li").slideDown();
			}
		}).keyup(function() {
			// fire the above change event after every letter
			$(this).change();
		});

        return input;
	};

	filterInput = listFilter('#trackshead', '#tracks');

	function escapeRegExp(string) {
		return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
	}

	function replaceAll(string, find, replace) {
		return string.replace(new RegExp(escapeRegExp(find), 'g'), replace);
	}

	// socket shit
	socket.on('user change', function(data) {
		$('#users').html(data);
	});

	socket.on('setvolume', function(data) {
		$("#volslider").val(parseInt(data));
	});

	socket.on('refreshList', function() {
		refreshTracks();
	});

	$("#volslider").change(function() {
		var val = $(this).val();
		socket.emit('changevolume', val);
	});
});
