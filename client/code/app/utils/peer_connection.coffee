adapter = require('./adapter')

class PC
  constructor: (@peer, @passive, @user) ->
    _.extend @, Backbone.Events

    @log "Creating PeerConnection."

    #config       = {iceServers: [{url: "stun:stun.l.google.com:19302"}]}
    constraints  = {optional: [{'DtlsSrtpKeyAgreement': true}, {'RtpDataChannels': true}]}
    
    # Force the use of a number IP STUN server for Firefox.
    #if adapter.webrtcDetectedBrowser is "firefox"
    #  config = iceServers: [url: "stun:23.21.150.121"]  

    config = {iceServers: [{url: 'stun:88.198.32.137:3479'}, {url: 'turn:88.198.32.137:3478?transport=udp', username: 'vmux', credential:'23c50f88-1c92-4a64-a803-69a2fa5d9a4a'}]}

    @pc = new adapter.RTCPeerConnection(config, constraints)

    @pc.onaddstream      = @onRemoteStreamAdded
    @pc.onremovestream   = @onRemoteStreamRemoved

    @pc.onicecandidate   = (event) =>
      if event.candidate
        @sendSignal
          type:       "candidate", 
          label:      event.candidate.sdpMLineIndex, 
          id:         event.candidate.sdpMid, 
          candidate:  event.candidate.candidate

    if @passive
      @pc.ondatachannel = (event) =>
        @attachEvents(event.channel)
    else
      channel = @pc.createDataChannel('vmux', {reliable: false})
      @attachEvents(channel)

  attachLocalStream: (stream) ->
    @pc.addStream stream

  attachEvents: (channel) ->
    @datachannel = channel

    channel.onopen    = =>
      @log 'DataChannel connection opened'
      @trigger 'datachannelopen', @

    channel.onclose   = =>
      @log 'DataChannel connection closed'
      @trigger 'datachannelclose', @

    channel.onmessage = =>
      @log "Message: #{event.data}"
      @trigger 'message', event.data

  sendMessage: (msg) =>
    @datachannel.send msg

  initiate: ->
    constraints = 
      optional: []
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
 
    @pc.createOffer (sdp) =>
      @pc.setLocalDescription sdp
      @sendSignal sdp
    ,
    =>
      @log "Error creating offer"
    , constraints
  

  processOffer: (msg) ->
    @log "Processing offer"
    constraints = 
      optional: []
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true

    @pc.setRemoteDescription new adapter.RTCSessionDescription(msg)
    @pc.createAnswer (sdp) =>
      @pc.setLocalDescription sdp
      @sendSignal sdp
    ,
    =>
      @log "Error creating answer"
    , constraints


  processAnswer: (msg) ->
    @log "Processing answer"
    @pc.setRemoteDescription new adapter.RTCSessionDescription(msg)

  addCandidate: (msg) ->
    #@log "Adding candidate"
    candidate = new adapter.RTCIceCandidate
      sdpMLineIndex: msg.label
      candidate: msg.candidate
    @pc.addIceCandidate candidate

  onRemoteStreamAdded: (event) =>
    @log "Remote stream added."
    @trigger 'remoteStreamAdded', event.stream
    @trigger 'open'

  onRemoteStreamRemoved: (event) =>
    @log "Remote stream removed."
    @trigger 'remoteStreamRemoved'

  hangup: =>
    @log 'Hanging up'
    @sendSignal type: 'bye'
    @close()
 
  close: =>
    @log 'Closing PeerConnection'
    @trigger 'close'
    @pc.close()

  log: (msg) =>
    console.debug "[#{@peer}] #{msg}"

  sendSignal: (message) ->
    ss.rpc 'vmux.signal', @peer, message

  muteAudio: =>
    track.enabled = false for track in localStream.getAudioTracks()
  
  unmuteAudio: =>
    track.enabled = true for track in localStream.getAudioTracks()

  muteVideo: =>
    track.enabled = false for track in localStream.getVideoTracks()
  
  unmuteVideo: =>
    track.enabled = true for track in localStream.getVideoTracks()

module.exports = PC
