#    Copyright (C) 2015 Evgeny Igumnov http://evgeny.igumnov.com igumnov@gmail.com
#
#     This program is free software: you can redistribute it and/or  modify
#    it under the terms of the GNU Affero General Public License, version 3,
#    as published by the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
login = null
api = null
network = null
wsNotification = null
wsNotificationMessages = false
wsNotificationPosts = false

class ApiManager
  constructor: (@Friend, @User, @PostAdd, @MessageAdd, @q, @friends = [], @publicKeys = []) ->

  getUserObject: (id, networkId, password = '') ->
    User = @User
    return @q((success, error) ->
      User.get(
        {
          userId: id
          networkId: networkId
        }
        (data) ->
          u = new UserObject(id, password)
          u.setPublicKeyBase64(data.publicKey)
          u.isActive = data.isActive
          try
            u.setPrivateKeyBase64(data.privateKey)
          catch e
          success(u)
        (err) ->
          error(err)
      )
    )

  messageToFriend: (fromId, friendId, body, created, image, file) ->
    post = new MessageObject(friendId, fromId, fromId, body, created, undefined, image, file)
    friend = new UserObject(friendId, '')
    PostAdd = @MessageAdd
    @User.get(
      {
        userId: friendId
        networkId: network
      }
      (data) ->
        friend.setPublicKeyBase64(data.publicKey)
        cipherBase64 = post.getCipherBase64(friend.publicKey)
        bodyBase64 = post.getBodyBase64()
        md = forge.md.sha256.create()
        md.update(bodyBase64, 'utf8')
        signature = forge.util.encode64(login.privateKey.sign(md))
        imageBase64 = ''
        fileBase64 = ''
        if(post.imageBody != undefined )
          imageBase64 = post.getImageBodyBase64()
        if(post.fileBody != undefined )
          fileBase64 = post.getFileBodyBase64()
        PostAdd.add(
          {sign: window.encodeURIComponent(signature)}
          {
            userId: friendId
            authorId: fromId
            friendId: fromId
            publishDate: post.publishDate
            body: bodyBase64
            imageBody: imageBase64
            fileBody: fileBase64
            networkId: network
            cipher: cipherBase64
          }
          (data) ->
          (err) -> alert err.data
        )
      (err) -> alert err.data
    )

  postToFriend: (fromId, friendId, body, created, image, file) ->
    post = new PostObject(friendId, fromId, body, created, undefined, image, file)
    friend = new UserObject(friendId, '')
    PostAdd = @PostAdd
    @User.get(
      {
        userId: friendId
        networkId: network
      }
      (data) ->
        friend.setPublicKeyBase64(data.publicKey)
        cipherBase64 = post.getCipherBase64(friend.publicKey)
        bodyBase64 = post.getBodyBase64()
        md = forge.md.sha256.create()
        md.update(bodyBase64, 'utf8')
        signature = forge.util.encode64(login.privateKey.sign(md))
        imageBase64 = ''
        fileBase64 = ''
        if(post.imageBody != undefined )
          imageBase64 = post.getImageBodyBase64()
        if(post.fileBody != undefined )
          fileBase64 = post.getFileBodyBase64()
        PostAdd.add(
          {sign: window.encodeURIComponent(signature)}
          {
            userId: friendId
            authorId: fromId
            publishDate: post.publishDate
            body: bodyBase64
            imageBody: imageBase64
            fileBody: fileBase64
            networkId: network
            cipher: cipherBase64
          }
          (data) ->
          (err) -> alert err.data
        )
      (err) -> alert err.data
    )

  loadFriends: (all = false) ->
    md = forge.md.sha256.create()
    md.update("friends", 'utf8')
    signature = forge.util.encode64(login.privateKey.sign(md))
    @Friend.get({
        userId: login.id
        sign: window.encodeURIComponent(signature)
        networkId: network
        all: all
      }
      (data) ->
        if(!all)
          @friends = data
    ).$promise


class PostObject
  constructor: (@userId, @authorId, @body = '', @publishDate = new Date().getTime(), @cipher = '', @imageBody, @fileBody) ->
    if(@cipher == '')
      key = forge.random.getBytesSync(32);
      iv = forge.random.getBytesSync(32);
      @cipher = {
        key: key
        iv: iv
      }

  getCipherBase64: (key) ->
    forge.util.encode64(key.encrypt(forge.util.encodeUtf8(angular.toJson(@cipher)), 'RSA-OAEP',
      {md: forge.md.sha256.create()}))

  setCipherBase64: (key, cipher) ->
    @cipher = angular.fromJson(forge.util.decodeUtf8(key.decrypt(forge.util.decode64(cipher), 'RSA-OAEP',
      {md: forge.md.sha256.create()})))

  getBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@body)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @body = forge.util.decodeUtf8(d.output.getBytes())

  getImageBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@imageBody)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setImageBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @imageBody = forge.util.decodeUtf8(d.output.getBytes())


  getFileBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@fileBody)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setFileBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @fileBody = forge.util.decodeUtf8(d.output.getBytes())


class MessageObject
  constructor: (@userId, @authorId, @friendId, @body = '', @publishDate = new Date().getTime(), @cipher = '', @imageBody, @fileBody) ->
    if(@cipher == '')
      key = forge.random.getBytesSync(32);
      iv = forge.random.getBytesSync(32);
      @cipher = {
        key: key
        iv: iv
      }

  getCipherBase64: (key) ->
    forge.util.encode64(key.encrypt(forge.util.encodeUtf8(angular.toJson(@cipher)), 'RSA-OAEP',
      {md: forge.md.sha256.create()}))

  setCipherBase64: (key, cipher) ->
    @cipher = angular.fromJson(forge.util.decodeUtf8(key.decrypt(forge.util.decode64(cipher), 'RSA-OAEP',
      {md: forge.md.sha256.create()})))

  getBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@body)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @body = forge.util.decodeUtf8(d.output.getBytes())

  getImageBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@imageBody)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setImageBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @imageBody = forge.util.decodeUtf8(d.output.getBytes())


  getFileBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv: @cipher.iv});
    c.update(forge.util.createBuffer(forge.util.encodeUtf8(@fileBody)));
    c.finish();
    forge.util.encode64(c.output.getBytes())

  setFileBodyBase64: (body) ->
    bodyOriginal = forge.util.decode64(body)
    buffer = forge.util.createBuffer()
    buffer.putBytes(bodyOriginal)
    d = forge.cipher.createDecipher('AES-CBC', @cipher.key)
    d.start({iv: @cipher.iv})
    d.update(buffer)
    d.finish()
    @fileBody = forge.util.decodeUtf8(d.output.getBytes())


class UserObject
  constructor: (@id, @password, @privateKey = null, @publicKey = null, @isActive = true) ->

  generateKeyPair: () ->
    keypair = forge.rsa.generateKeyPair({bits: 2048, e: 0x10001});
    @privateKey = keypair.privateKey
    @publicKey = keypair.publicKey

  getPrivateKeyBase64: () ->
    pem = forge.pki.encryptRsaPrivateKey(@privateKey, @password)
    forge.util.encode64(forge.asn1.toDer(forge.pki.encryptedPrivateKeyFromPem(pem), {algorithm: 'aes256'}).getBytes())

  setPrivateKeyBase64: (key) ->
    @privateKey = forge.pki.privateKeyFromAsn1(forge.pki.decryptPrivateKeyInfo(forge.asn1.fromDer(forge.util.decode64(key)),
      @password))
    @privateKey


  getPublicKeyBase64: () ->
    forge.util.encode64(forge.asn1.toDer(forge.pki.publicKeyToAsn1(@publicKey)).getBytes())

  setPublicKeyBase64: (key) ->
    @publicKey = forge.pki.publicKeyFromAsn1(forge.asn1.fromDer(forge.util.decode64(key)))


app = angular.module 'protectedNetApp', ['ui.bootstrap', 'ngResource', 'ngRoute', 'ngWebSocket']


app.controller('RedirectCtrl', RedirectCtrl = ($scope, $location, Network) ->
    Network.get(
      {networkId: network}
      (data) ->
        if(login == null)
          $location.path("/posts")
        else
          if(data.adminId == login.id)
            $location.path("/posts")
#$location.path("/admin")
          else
            $location.path("/posts")
      (err) ->
        alert(err.data)
        window.location.href = "/"
    )
)
app.controller('AdminCtrl', AdminCtrl = ($scope, $modal, $location, UserAdd, Network) ->
    Network.get(
      {networkId: network}
      (data) ->
        $scope.network = data
    )
    api.mainScope.newMembers = false;
    $scope.login = login
    $scope.reloadFriends = () ->
      api.loadFriends(true).then((friends) -> $scope.friends = friends)
    if(login == null)
      $location.path("/")
    else
      $scope.reloadFriends()

    $scope.activate = (member) ->
      member.isActive = true
      md = forge.md.sha256.create()
      md.update(member.id, 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      UserAdd.update(
        {
          sign: signature
          networkId: network
        }
        member
        (data) -> $scope.reloadFriends()
        (err) -> $scope.reloadFriends()
      )

    $scope.deactivate = (member) ->
      member.isActive = false
      md = forge.md.sha256.create()
      md.update(member.id, 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      UserAdd.update(
        {
          sign: signature
          networkId: network
        }
        member
        (data) -> $scope.reloadFriends()
        (err) -> $scope.reloadFriends()
      )
    $scope.pay = () ->
      modalInstance = $modal.open({
        templateUrl: '/part/bitcoin'
        controller: 'BitcoinModalCtrl'
      })
)
app.controller('BitcoinModalCtrl', BitcoinModalCtrl = ($scope, $modalInstance, Bitcoin) ->
    $scope.hide = false
    Bitcoin.get(
      {networkId: network}
      (data) ->
        $scope.address = data.address
        $scope.hide = true
      (err) ->
        alert(err.data)
    )
    $scope.close =  () ->
      $modalInstance.dismiss('cancel')


)
app.controller('MessageCtrl',
  MessageCtrl = ($scope, $routeParams, MessageAdd, MessageGet, MessageFile, MessageImage, Dialogs, $q) ->
    $scope.showNext = false
    api.messageScope = $scope
    api.mainScope.newMessages = false;

    $scope.message = {
      body: ""
    }


    $scope.messageToId = $routeParams.toId;


    $scope.messages = []
    $scope.lastEntryDate = 0
    $scope.loadOlder = () ->
      $scope.loadDialogs()
      $scope.loadPosts()

    $scope.reloadPosts = () ->
      if($scope.messageToId != undefined)
        $scope.messages = []
        $scope.lastEntryDate = 0
        $scope.loadPosts()


    $scope.download = (file, fileName) ->
      link = document.createElement("a");
      link.download = fileName;
      link.href = file;
      link.click();

    $scope.loadDialogs = () ->
      md = forge.md.sha256.create()
      md.update("dialogs", 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      Dialogs.get({
          userId: login.id
          networkId: network
          sign: window.encodeURIComponent(signature)
        }
        (data) ->
          $scope.dialogs = data
          if(data.length == 0)
            api.loadFriends().then((friends) ->
              for friend,i in friends
                if(friend.id != login.id)
                  $scope.dialogs.push({friendId: friend.id})
              if($scope.messageToId == undefined )
                $scope.messageToId = $scope.dialogs[0].friendId
                $scope.reloadPosts()
            )
          else
            if($scope.messageToId == undefined )
              $scope.messageToId = $scope.dialogs[0].friendId
              $scope.reloadPosts()
      )

    if(!wsNotificationMessages)
      wsNotification.onMessage((msg) ->
        notification = JSON.parse(msg.data)
        if(notification.fromId == api.messageScope.messageToId)
          api.messageScope.loadPosts(true)
          api.messageScope.loadDialogs()
        else
          api.messageScope.loadDialogs()
      )
      wsNotificationMessages = true


    $scope.loadPosts = (begin) ->
      if(begin == undefined)
        lastEntryDate = $scope.lastEntryDate
      else
        lastEntryDate = 0
      md = forge.md.sha256.create()
      md.update("messages", 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      MessageGet.get({
          userId: login.id
          networkId: network
          friendId: $scope.messageToId
          sign: window.encodeURIComponent(signature)
          fromDate: lastEntryDate
        }
        (data) ->
          if(begin == undefined)
            if(data.length == 10)
              $scope.showNext = "true"
            else
              $scope.showNext = false
            $scope.messages = [$scope.messages, data].reduce (a, b) ->
              a.concat b
          else
            $scope.messages.unshift(data[0])
            tmpD = data[0]
            data = []
            data[0] = tmpD
          for d in data
            if(begin == undefined)
              $scope.lastEntryDate = d.publishDate
            $q((success, error)->
              post = new MessageObject(login.id, d.authorId, d.friendId)
              post.setCipherBase64(login.privateKey, d.cipher)
              post.setBodyBase64(d.body)
              post.publishDate = d.publishDate
              jsonBody = angular.fromJson(post.body)
              d.body = jsonBody.message
              lines = d.body.match(/[^\r\n]+/g)
              d.bodies = []
              if(lines != null )
                for line in lines
                  d.bodies.push({body: line})
              else
                d.bodies[0] = {body: d.body}
              if(d.imageBody == 'image')
                md = forge.md.sha256.create()
                md.update("image", 'utf8')
                sign = forge.util.encode64(login.privateKey.sign(md))
                MessageImage.get(
                  {
                    userId: d.userId
                    friendId: d.friendId
                    publishDate: d.publishDate
                    networkId: d.networkId
                    sign: window.encodeURIComponent(sign)
                  }
                  (image) ->
                    post.setImageBodyBase64(image.imageBody)
                    imageJsonBody = angular.fromJson(post.imageBody)
                    if(imageJsonBody.image != undefined )
                      for p in $scope.messages
                        if(post.publishDate == p.publishDate)
                          p.image = "data:image/png;base64," + imageJsonBody.image
                )


              if(d.fileBody == 'file')
                md = forge.md.sha256.create()
                md.update("file", 'utf8')
                sign = forge.util.encode64(login.privateKey.sign(md))
                MessageFile.get(
                  {
                    userId: d.userId
                    friendId: d.friendId
                    publishDate: d.publishDate
                    networkId: d.networkId
                    sign: window.encodeURIComponent(sign)
                  }
                  (file) ->
                    post.setFileBodyBase64(file.fileBody)
                    fileJsonBody = angular.fromJson(post.fileBody)
                    if(fileJsonBody.file != undefined )
                      for p in $scope.messages
                        if(post.publishDate == p.publishDate)
                          p.fileShow = true
                          p.fileName = fileJsonBody.fileName
                          p.file = "data:application/octet-stream;base64," + fileJsonBody.file
                )
            )
        (err) -> alert(err.data)
      )

    $scope.loadDialogs()
    $scope.reloadPosts()


    if(login != null)
      $scope.messageShow = ''
    else
      $scope.messageShow = 'none'


    $scope.add = () ->
      f = document.getElementById('image').files[0]
      if(f != undefined )
        r = new FileReader()
        r.onloadend = (e) ->
          buffer = forge.util.createBuffer()
          buffer.putBytes(e.target.result)
          $scope.addFile(forge.util.encode64(buffer.getBytes()))
        r.readAsBinaryString(f)
      else
        $scope.addFile()

    $scope.addFile = (image) ->
      f = document.getElementById('file').files[0]
      if(f != undefined )
        r = new FileReader()
        r.onloadend = (e) ->
          buffer = forge.util.createBuffer()
          buffer.putBytes(e.target.result)
          $scope.sendMessage(image, forge.util.encode64(buffer.getBytes()), f.name)
        r.readAsBinaryString(f)
      else
        $scope.sendMessage(image)

    $scope.sendMessage = (image, file, fileName) ->
      document.getElementById('form').reset()
      bodyObject = {message: $scope.message.body}
      if(image != undefined )
        imageJson = angular.toJson({image: image})
      if(file != undefined )
        fileJson = angular.toJson({file: file, fileName: fileName})
      bodyJson = angular.toJson(bodyObject)
      post = new MessageObject(login.id, login.id, $scope.messageToId, bodyJson, new Date().getTime(), undefined,
        imageJson, fileJson)
      cipherBase64 = post.getCipherBase64(login.publicKey)
      bodyBase64 = post.getBodyBase64()
      md = forge.md.sha256.create()
      md.update(bodyBase64, 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      imageBase64 = ''
      fileBase64 = ''
      if(imageJson != undefined )
        imageBase64 = post.getImageBodyBase64()
      if(fileJson != undefined )
        fileBase64 = post.getFileBodyBase64()
      MessageAdd.add(
        {
          sign: window.encodeURIComponent(signature)
        }
        {
          userId: post.userId
          authorId: post.authorId
          networkId: network
          friendId: post.friendId
          publishDate: post.publishDate
          body: bodyBase64
          imageBody: imageBase64
          fileBody: fileBase64
          cipher: cipherBase64
        }
        (data) ->
          api.messageToFriend(login.id, post.friendId, bodyJson, data.publishDate, imageJson, fileJson)
          $scope.loadPosts(true)
          $scope.message.body = ""
          $scope.loadDialogs()

        (err) -> alert err.data
      )
)


app.controller('StartCtrl', StartCtrl = ($scope, $timeout, UserAdd, Network) ->
    $scope.user = {
      userName: ''
      networkId: ''
      userPassword: ''
    }
    $scope.errNetworkAlready = 'none'
    $scope.startGeneration = 'none'
    $scope.submitPressed = false
    $scope.go = () ->
      window.location = $scope.networkgo

    $scope.change = () ->
      Network.get(
        {networkId: $scope.user.networkId}
        (data) ->
          $scope.errNetworkAlready = ''
        (err) ->
          $scope.errNetworkAlready = 'none'
      )
    $scope.create = () ->
      $scope.submitPressed = true
      $scope.startGeneration = ''
      $timeout(()->
        u = new UserObject($scope.user.userName, $scope.user.userPassword)
        u.generateKeyPair()
        user = {
          id: u.id
          privateKey: u.getPrivateKeyBase64()
          publicKey: u.getPublicKeyBase64()
          networkId: $scope.user.networkId
          isActive: true
        }
        UserAdd.add(
          {createNetwork: true}
          user
          (data) ->
            alert $scope.redirect
            window.location = $scope.user.networkId
          (err) ->
            alert err.data
            $scope.startGeneration = 'none'
            $scope.submitPressed = false
        )
      , 1000)
    $scope.onLoadPageDisplay = '';
)

app.controller('FriendCtrl', FriendCtrl = ($scope) ->
    $scope.login = login

    $scope.reloadFriends = () ->
      api.loadFriends().then((friends) -> $scope.friends = friends)

    if(login != null)
      $scope.reloadFriends()
      $scope.friendShow = ''
    else
      $scope.friendShow = 'none'
)

app.controller('PostCtrl', PostCtrl = ($scope, PostGet, PostAdd, PostFile, PostImage, $timeout, $q) ->
    $scope.login = login

    $scope.showNext = false


    api.postScope = $scope
    api.mainScope.newPosts = false;
    $scope.post = {
      body: ""
    }
    $scope.posts = []
    $scope.lastEntryDate = 0
    $scope.loadOlder = () ->
      $scope.loadPosts()

    $scope.reloadPosts = () ->
      $scope.posts = []
      $scope.lastEntryDate = 0
      $scope.loadPosts()


    $scope.download = (file, fileName) ->
      link = document.createElement("a");
      link.download = fileName;
      link.href = file;
      link.click();

    $scope.loadPosts = (begin) ->
      if(begin == undefined)
        lastEntryDate = $scope.lastEntryDate
      else
        lastEntryDate = 0
      md = forge.md.sha256.create()
      md.update("posts", 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      PostGet.get({
          userId: login.id
          networkId: network
          sign: window.encodeURIComponent(signature)
          fromDate: lastEntryDate
        }
        (data) ->
          api.mainScope.newPosts = false
          if(begin == undefined)
            if(data.length == 10)
              $scope.showNext = "true"
            else
              $scope.showNext = false
            $scope.posts = [$scope.posts, data].reduce (a, b) ->
              a.concat b
          else
            $scope.posts.unshift(data[0])
            tmpD = data[0]
            data = []
            data[0] = tmpD
          for d in data
            if(begin == undefined)
              $scope.lastEntryDate = d.publishDate
            $q((success, error)->
              post = new PostObject(login.id, d.authorId)
              post.setCipherBase64(login.privateKey, d.cipher)
              post.setBodyBase64(d.body)
              post.publishDate = d.publishDate
              jsonBody = angular.fromJson(post.body)
              d.body = jsonBody.message
              lines = d.body.match(/[^\r\n]+/g)
              d.bodies = []
              if(lines != null )
                for line in lines
                  d.bodies.push({body: line})
              else
                d.bodies[0] = {body: d.body}
              if(d.imageBody == 'image')
                md = forge.md.sha256.create()
                md.update("image", 'utf8')
                sign = forge.util.encode64(login.privateKey.sign(md))
                PostImage.get(
                  {
                    userId: d.userId
                    authorId: d.authorId
                    publishDate: d.publishDate
                    networkId: d.networkId
                    sign: window.encodeURIComponent(sign)
                  }
                  (image) ->
                    post.setImageBodyBase64(image.imageBody)
                    imageJsonBody = angular.fromJson(post.imageBody)
                    if(imageJsonBody.image != undefined )
                      for p in $scope.posts
                        if(post.publishDate == p.publishDate)
                          p.image = "data:image/png;base64," + imageJsonBody.image
                )


              if(d.fileBody == 'file')
                md = forge.md.sha256.create()
                md.update("file", 'utf8')
                sign = forge.util.encode64(login.privateKey.sign(md))
                PostFile.get(
                  {
                    userId: d.userId
                    authorId: d.authorId
                    publishDate: d.publishDate
                    networkId: d.networkId
                    sign: window.encodeURIComponent(sign)
                  }
                  (file) ->
                    post.setFileBodyBase64(file.fileBody)
                    fileJsonBody = angular.fromJson(post.fileBody)
                    if(fileJsonBody.file != undefined )
                      for p in $scope.posts
                        if(post.publishDate == p.publishDate)
                          p.fileShow = true
                          p.fileName = fileJsonBody.fileName
                          p.file = "data:application/octet-stream;base64," + fileJsonBody.file
                )
            )
        (err) -> alert(err.data)
      )


    if(login != null)
      $scope.reloadPosts()
      $scope.postShow = ''
    else
      $scope.postShow = 'none'

    if(!wsNotificationPosts)
      wsNotification.onMessage((msg) ->
        notification = JSON.parse(msg.data)
        #console.log(notification)
        if(notification.fromId == null && notification.toId != null)
          api.postScope.loadPosts(true)
      )
      wsNotificationPosts = true


    $scope.add = () ->
      f = document.getElementById('image').files[0]
      if(f != undefined )
        r = new FileReader()
        r.onloadend = (e) ->
          buffer = forge.util.createBuffer()
          buffer.putBytes(e.target.result)
          $scope.addFile(forge.util.encode64(buffer.getBytes()))
        r.readAsBinaryString(f)
      else
        $scope.addFile()

    $scope.addFile = (image) ->
      f = document.getElementById('file').files[0]
      if(f != undefined )
        r = new FileReader()
        r.onloadend = (e) ->
          buffer = forge.util.createBuffer()
          buffer.putBytes(e.target.result)
          $scope.sendPost(image, forge.util.encode64(buffer.getBytes()), f.name)
        r.readAsBinaryString(f)
      else
        $scope.sendPost(image)

    $scope.sendPost = (image, file, fileName) ->
      document.getElementById('form').reset()
      bodyObject = {message: $scope.post.body}
      if(image != undefined )
        imageJson = angular.toJson({image: image})
      if(file != undefined )
        fileJson = angular.toJson({file: file, fileName: fileName})
      #console.log(fileJson)
      bodyJson = angular.toJson(bodyObject)
      post = new PostObject(login.id, login.id, bodyJson, new Date().getTime(), undefined, imageJson, fileJson)
      cipherBase64 = post.getCipherBase64(login.publicKey)
      bodyBase64 = post.getBodyBase64()
      md = forge.md.sha256.create()
      md.update(bodyBase64, 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      imageBase64 = ''
      fileBase64 = ''
      if(imageJson != undefined )
        imageBase64 = post.getImageBodyBase64()
      if(fileJson != undefined )
        fileBase64 = post.getFileBodyBase64()
      PostAdd.add(
        {
          sign: window.encodeURIComponent(signature)
        }
        {
          userId: post.userId
          authorId: post.authorId
          networkId: network
          publishDate: post.publishDate
          body: bodyBase64
          imageBody: imageBase64
          fileBody: fileBase64
          cipher: cipherBase64
        }
        (data) ->
          api.loadFriends().then((friends) ->
            for f in friends
              if(login.id != f.id)
                api.postToFriend(login.id, f.id, bodyJson, data.publishDate, imageJson, fileJson)
          )
          $scope.loadPosts(true)
          $scope.post = {
            body: ""
          }

        (err) -> alert err.data
      )
)

app.controller('MainCtrl',
  MainCtrl = ($scope, $modal, $q, $location, $websocket, UserGet, PostAdd, Friend, Network, MessageAdd) ->
    $scope.newPosts = false
    $scope.newMessages = false
    $scope.newMembers = false
    parser = document.createElement('a');
    parser.href = window.location.href
    network = parser.pathname.replace(new RegExp("/", 'g'), "")

    $scope.menuShow = 'none'
    $scope.showAdmin = 'none';

    $scope.login = false
    api = new ApiManager(Friend, UserGet, PostAdd, MessageAdd, $q)
    api.mainScope = $scope

    $scope.register = () ->
      modalInstance = $modal.open({
        templateUrl: '/modal/register',
        controller: 'RegisterModalCtrl'
      })

    $scope.login = () ->
      api.getUserObject($scope.user.userName, network, $scope.user.userPassword)
      .then(
        (data)->
          if(data.privateKey != null)
            if(!data.isActive)
              alert $scope.notactive
            else
              $scope.login = true
              $scope.loginUser = data
              $scope.postShow = ''
              $scope.menuShow = ''
              $scope.network = network
              login = data
              md = forge.md.sha256.create()
              md.update("notifications", 'utf8')
              signature = forge.util.encode64(login.privateKey.sign(md))
              #wsNotification = $websocket('ws://localhost:9000/websocket/changeevent/' + network + '/' + login.id + '/' + encodeURIComponent(signature))
              wsNotification = $websocket('wss://protectednet.io/websocket/changeevent/' + network + '/' + login.id + '/' + encodeURIComponent(signature))
              wsNotification.onMessage((msg) ->
                notification = JSON.parse(msg.data)
                if(notification.fromId == null && notification.toId == null)
                  $scope.newMembers = true
                if(notification.fromId == null && notification.toId != null)
                  $scope.newPosts = true
                if(notification.fromId != null && notification.toId != null)
                  $scope.newMessages = true
              )
              wsNotification.onOpen(() ->
                wsNotification.send(JSON.stringify({
                  networkId: network
                  fromId: ""
                  toId: ""
                }))
              )
              api.loadFriends()
              Network.get(
                {networkId: network}
                (data) ->
                  if(data.adminId == login.id)
                    $scope.showAdmin = '';
              )
              $location.path("/reload")
          else
            alert $scope.errorIncorrectPassword
        (err)->
          alert err.data
      )
    $scope.onLoadPageDisplay=''
)

app.controller('RegisterModalCtrl', RegisterModalCtrl = ($scope, UserAdd, UserGet, $modalInstance, $timeout) ->
    $scope.startGeneration = "none"
    $scope.user = {userName: "", userPassword: ""}
    $scope.submitPressed = false
    $scope.userExists = 'none'

    $scope.change = () ->
      UserGet.get(
        {
          userId: $scope.user.userName
          networkId: network
        }
        (data) ->
          $scope.userExists = ''
        (err) ->
          $scope.userExists = 'none'
      )

    $scope.ok = () ->
      $scope.startGeneration = ""
      $scope.submitPressed = true
      $timeout(() ->
        u = new UserObject($scope.user.userName, $scope.user.userPassword)
        u.generateKeyPair()
        user = {
          id: u.id
          privateKey: u.getPrivateKeyBase64()
          publicKey: u.getPublicKeyBase64()
          networkId: network
          isActive: false
        }
        UserAdd.add(
          {}
          user
          (data) ->
            alert $scope.success
            $modalInstance.close()
          (err) ->
            $scope.startGeneration = ""
            $scope.submitPressed = false
            alert err.data
        )
      , 1000)
    $scope.close = () ->
      $modalInstance.dismiss('cancel')
)


app.factory 'UserGet', [
  '$resource'
  ($resource) ->
    $resource '/rest/user/:userId/:networkId', {userId: '@userId', networkId: '@networkId'},
      get:
        method: 'GET'
        cache: false
        isArray: false

]

app.factory 'UserAdd', [
  '$resource'
  ($resource) ->
    $resource '/rest/user', {},
      add:
        method: 'POST'
        cache: false
        isArray: false
      update:
        method: 'PUT'
        cache: false
        isArray: false
]


app.factory 'PostImage', [
  '$resource'
  ($resource) ->
    $resource '/rest/postimage/:userId/:authorId/:publishDate/:networkId/:sign', {
        userId: '@userId',
        authorId: '@authorId',
        publishDate: '@publishDate',
        networkId: '@networkId',
        sign: '@sign'
      },
      get:
        method: 'GET'
        cache: false
        isArray: false

]
app.factory 'PostFile', [
  '$resource'
  ($resource) ->
    $resource '/rest/postfile/:userId/:authorId/:publishDate/:networkId/:sign', {
        userId: '@userId',
        authorId: '@authorId',
        publishDate: '@publishDate',
        networkId: '@networkId',
        sign: '@sign'
      },
      get:
        method: 'GET'
        cache: false
        isArray: false

]


app.factory 'MessageImage', [
  '$resource'
  ($resource) ->
    $resource '/rest/messageimage/:userId/:friendId/:publishDate/:networkId/:sign', {
        userId: '@userId',
        friendId: '@friendId',
        publishDate: '@publishDate',
        networkId: '@networkId',
        sign: '@sign'
      },
      get:
        method: 'GET'
        cache: false
        isArray: false

]
app.factory 'MessageFile', [
  '$resource'
  ($resource) ->
    $resource '/rest/messagefile/:userId/:friendId/:publishDate/:networkId/:sign', {
        userId: '@userId',
        friendId: '@friendId',
        publishDate: '@publishDate',
        networkId: '@networkId',
        sign: '@sign'
      },
      get:
        method: 'GET'
        cache: false
        isArray: false

]


app.factory 'PostGet', [
  '$resource'
  ($resource) ->
    $resource '/rest/post/:userId/:networkId/:sign', {userId: '@userId', networkId: '@networkId', sign: '@sign'},
      get:
        method: 'GET'
        cache: false
        isArray: true

]

app.factory 'PostAdd', [
  '$resource'
  ($resource) ->
    $resource '/rest/post/:sign', {sign: '@sign'},
      add:
        method: 'POST'
        cache: false
        isArray: false

]

app.factory 'MessageAdd', [
  '$resource'
  ($resource) ->
    $resource '/rest/message/:sign', {sign: '@sign'},
      add:
        method: 'POST'
        cache: false
        isArray: false
]

app.factory 'MessageGet', [
  '$resource'
  ($resource) ->
    $resource '/rest/message/:userId/:networkId/:friendId/:sign', {
        userId: '@userId',
        networkId: '@networkId',
        friendId: '@friendId',
        sign: '@sign'
      },
      get:
        method: 'GET'
        cache: false
        isArray: true

]

app.factory 'Dialogs', [
  '$resource'
  ($resource) ->
    $resource '/rest/dialog/:userId/:networkId/:sign', {userId: '@userId', networkId: '@networkId', sign: '@sign'},
      get:
        method: 'GET'
        cache: false
        isArray: true

]

app.factory 'Friend', [
  '$resource'
  ($resource) ->
    $resource '/rest/friend/:userId/:networkId/:sign', {userid: '@userid', networkId: '@networkId', sign: '@sign'},
      get:
        method: 'GET'
        cache: false
        isArray: true
]

app.factory 'Network', [
  '$resource'
  ($resource) ->
    $resource '/rest/network/:networkId', {networkId: '@networkId'},
      get:
        method: 'GET'
        cache: false
        isArray: false

]

app.factory 'Bitcoin', [
  '$resource'
  ($resource) ->
    $resource '/rest/bitcoin', {},
      get:
        method: 'GET'
        cache: false
        isArray: false

]

app.config([
  '$routeProvider',
  ($routeProvider) ->
    $routeProvider.when('/', {
      templateUrl: 'part/redirect',
      controller: 'RedirectCtrl'
    })
    .when('/posts', {
        templateUrl: 'part/posts',
        controller: 'PostCtrl'
      })
    .when('/members', {
        templateUrl: 'part/friends',
        controller: 'FriendCtrl'
      })
    .when('/admin', {
        templateUrl: 'part/admin',
        controller: 'AdminCtrl'
      })
    .when('/messages', {
        templateUrl: 'part/messages',
        controller: 'MessageCtrl'
      })
    .when('/messages/:toId', {
        templateUrl: 'part/messages',
        controller: 'MessageCtrl'
      })
    .otherwise({
        redirectTo: '/'
      })
])