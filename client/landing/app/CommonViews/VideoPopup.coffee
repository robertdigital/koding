class VideoPopupController extends KDController
  constructor:(options,data)->
    super options,data
    # if not @getSingleton("windowController").videoPopups?
    #   @getSingleton("windowController").videoPopups = []

    @videoPopups = []
    # log "VideoPopupController initialized"

  newPopup:(url, windowTitle, optionString, imageTitle, imageThumb)->
    # log "Arguments in newPopup",arguments
    newWindow = window.open url, windowTitle, optionString
    newWindow.onbeforeunload = (newWindowEvent)=>
      # log "VideoPopupController newPopup Window received onbeforeunload",newWindow
      newWindow.onbeforeunload = noop
      @closePopup newWindow
      undefined
    @videoPopups.push newWindow
    # log "VideoPopupController added window to stack"
    @emit "PopupOpened",newWindow,
      title : imageTitle
      thumb : imageThumb
    return newWindow

  listPopups:()->
    @videoPopups

  countPopups:()->
    @videoPopups.length

  focusWindowByName:(windowName)->
    for video in @videoPopups
      if video.name is windowName
        video.focus()

  closeWindowByName:(windowName)->
    for video in @videoPopups
      if video.name is windowName
        @closePopup video

  closePopup:(popupWindow)->
    # log "VideoPopupController closePopup called"
    for videoPopup,i in @videoPopups
      if popupWindow is videoPopup
        @videoPopups.splice i,1
        @emit "PopupClosed",popupWindow.name,i
    popupWindow?.close()
    # log "VideoPopup Controller closed a window"


class VideoPopupList extends KDListView
  constructor:(options,data)->
    super options,data
    @controller = @getSingleton("mainController").popupController

    @controller.on "PopupOpened", (popup,data) =>
      # log "VideoPopupList adding item",popup
      @addItem
        delegate : @
        name : popup.name or "New Window"
        title : data.title
        thumb : data.thumb

    @controller.on "PopupClosed", (popupName,index) =>
      # log "VideoPopupList removing item",popupName,index
      @removeItem {},{},index
      # @utils.wait => log "VideoPopupList items are",@items

    @on "FocusWindow", (windowName)->
      @controller.focusWindowByName windowName
    @on "CloseWindow", (windowName)->
      @controller.closeWindowByName windowName

class VideoPopupListItem extends KDListItemView
  constructor:(options,data)->
    super options,data
    @setData data

    @focusWindowBar = new KDView
      cssClass : "overlay-bar"
      partial : "Focus it"
      click : =>
        @getDelegate().emit "FocusWindow", @getData().name

    @closeWindowBar = new KDView
      cssClass : "overlay-bar"
      partial : "Close it"
      click : =>
        @getDelegate().emit "CloseWindow", @getData().name

  viewAppended:->
    @setTemplate @pistachio()
    @template.update()

  # click:()->
  #   @getDelegate().emit "FocusWindow", @getData().name

  pistachio:->
    """
    <div class="video-popup-list">
    {{#(title)}} ({{#(name)}})
    {{> @focusWindowBar}}
    {{> @closeWindowBar}}
    <img title="#{@getData().title}" src="#{@utils.proxifyUrl @getData().thumb}" />
    </div>
    """



class VideoPopup extends KDView

# THIS NEEDS A DELEGATE

  constructor:(options,data)->
    super options,data
    @setClass "hidden invisible"

    @embedData = data
    @options = options
    @controller = @getSingleton("mainController").popupController

    # log "New VideoPopup", options, data

  openVideoPopup:->
    h=@getDelegate().getHeight()
    w=@getDelegate().getWidth()
    t=@getDelegate().$().offset()
    @videoPopup?.close()
    @videoPopup = @controller.newPopup "http://localhost:3000/1.0/video-container.html", "KodingVideo_"+Math.random().toString(36).substring(7), "menubar=no,location=no,resizable=yes,titlebar=no,scrollbars=no,status=no,innerHeight=#{h},width=#{w},left=#{t.left+window.screenX},top=#{window.screenY+t.top+(window.outerHeight - window.innerHeight)}", @options.title, @options.thumb

    @utils.wait 1500, =>          # give the popup some time to open

      window.onfocus = =>         # once the user returns to the main view

        @utils.wait 500, =>       # user maybe just closed the popup

          if @videoPopup.length isnt 0

            window.onfocus = noop # reset the onfocus
            userChoice = no       # default selection is "Close the window"

            secondsToAutoClose = 10

            modal           = new KDModalView
              title         : "Do you want to keep the video running?"
              content       : "<p class='modal-video-close'>Your video will automatically end in <span class='countdown'>#{secondsToAutoClose}</span> seconds unless you click the 'Yes'-Button below.</p>"
              overlay       : yes
              buttons       :
                "No, close it" :
                  title     : "No, close it"
                  cssClass  : "modal-clean-gray"
                  callback  : =>
                    @videoPopup?.close()
                    modal.destroy()
                "Yes, keep it running" :
                  title     : "Yes, keep it running"
                  cssClass  : "modal-clean-green"
                  callback  : =>
                    modal.destroy()
                    userChoice = yes

            currentSeconds = secondsToAutoClose-1
            countdownInterval = window.setInterval =>
              modal.$("span.countdown").text currentSeconds--
            , 1000

            @utils.wait 1000*secondsToAutoClose, =>

              window.clearInterval countdownInterval

              unless userChoice
                @controller.closePopup @videoPopup
                modal.destroy()

      command =
        type   : "embed"
        embed  : @embedData
        coordinates :
          left : @options.popup?.left or t.left+window.screenX or 100
          top  : @options.popup?.top or window.screenY+t.top+(window.outerHeight - window.innerHeight) or 100

      if command and @videoPopup
        @videoPopup.postMessage command, "*"
