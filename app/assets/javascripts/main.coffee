# Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/
login = null
api = null
network = null

class ApiManager
  constructor: (@Friend, @User, @PostAdd, @q, @friends = [], @publicKeys = []) ->

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

  postToFriend: (fromId, friendId, body, created) ->
    post = new PostObject(friendId, fromId, body, created)
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
        md = forge.md.sha1.create()
        md.update(bodyBase64, 'utf8')
        signature = forge.util.encode64(login.privateKey.sign(md))
        PostAdd.add(
          {sign: window.encodeURIComponent(signature)}
          {
            userId: friendId
            authorId: fromId
            publishDate: post.publishDate
            body: bodyBase64
            networkId: network
            cipher: cipherBase64
          }
          (data) ->
          (err) -> alert err.data
        )
      (err) -> alert err.data
    )

  loadFriends: (all = false) ->
    md = forge.md.sha1.create()
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
  constructor: (@userId, @authorId, @body = '', @publishDate = new Date().getTime(), @cipher='') ->
    if(@cipher =='')
      key = forge.random.getBytesSync(32);
      iv = forge.random.getBytesSync(32);
      @cipher = {
        key:key
        iv:iv
      }

  getCipherBase64: (key) ->
    forge.util.encode64(key.encrypt(forge.util.encodeUtf8(angular.toJson(@cipher)),'RSA-OAEP',{md: forge.md.sha256.create()}))

  setCipherBase64: (key, cipher) ->
    @cipher = angular.fromJson(forge.util.decodeUtf8(key.decrypt(forge.util.decode64(cipher),'RSA-OAEP',{md: forge.md.sha256.create()})))

  getBodyBase64: () ->
    c = forge.cipher.createCipher('AES-CBC', @cipher.key);
    c.start({iv:  @cipher.iv});
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


app = angular.module 'protectedNetApp', ['ui.bootstrap', 'ngResource', 'ngRoute']


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
app.controller('AdminCtrl', AdminCtrl = ($scope, $location, UserAdd) ->
    $scope.reloadFriends = () ->
      api.loadFriends(true).then((friends) -> $scope.friends = friends)
    if(login == null)
      $location.path("/")
    else
      $scope.reloadFriends()

    $scope.activate = (member) ->
      console.log(member)
      member.isActive = true
      md = forge.md.sha1.create()
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
      console.log(member)
      member.isActive = false
      md = forge.md.sha1.create()
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
)
app.controller('MessageCtrl', MessageCtrl = ($scope) ->
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
)

app.controller('FriendCtrl', FriendCtrl = ($scope, Friend) ->
    $scope.reloadFriends = () ->
      api.loadFriends().then((friends) -> $scope.friends = friends)

    if(login != null)
      $scope.reloadFriends()
      $scope.friendShow = ''
    else
      $scope.friendShow = 'none'
)

app.controller('PostCtrl', PostCtrl = ($scope, PostGet, PostAdd) ->
    $scope.post= {
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


    $scope.loadPosts = () ->
      md = forge.md.sha1.create()
      md.update("posts", 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
      PostGet.get({
          userId: login.id
          networkId: network
          sign: window.encodeURIComponent(signature)
          fromDate: $scope.lastEntryDate
        }
        (data) ->
          $scope.posts = [$scope.posts, data].reduce (a, b) ->
            a.concat b
          for d in data
            post = new PostObject(login.id, data.authorId)
            post.setCipherBase64(login.privateKey, d.cipher)
            post.setBodyBase64(d.body)
            jsonBody = angular.fromJson(post.body)
            d.body = jsonBody.message
            if(jsonBody.image != undefined )
              d.image="data:image/png;base64," + jsonBody.image
            $scope.lastEntryDate = d.publishDate
      )

    if(login != null)
      $scope.reloadPosts()
      $scope.postShow = ''
    else
      $scope.postShow = 'none'

    $scope.add = () ->
      f = document.getElementById('file').files[0]
      if(f != undefined )
        r = new FileReader()
        r.onloadend = (e) ->
          buffer = forge.util.createBuffer()
          buffer.putBytes(e.target.result)
          $scope.sendPost(forge.util.encode64(buffer.getBytes()))
        r.readAsBinaryString(f)
      else
        $scope.sendPost()
    $scope.sendPost = (image) ->
      if(image == undefined)
        bodyJson = angular.toJson(
          {message: $scope.post.body}
        )
      else
        bodyJson = angular.toJson(
          {
            message: $scope.post.body
            image: image
          }
        )
      body = bodyJson
      post = new PostObject(login.id, login.id, body, new Date().getTime())
      cipherBase64 = post.getCipherBase64(login.publicKey)
      bodyBase64 = post.getBodyBase64()
      md = forge.md.sha1.create()
      md.update(bodyBase64, 'utf8')
      signature = forge.util.encode64(login.privateKey.sign(md))
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
          cipher: cipherBase64
        }
        (data) ->
          api.loadFriends().then((friends) ->
            for f in friends
              if(login.id != f.id)
                api.postToFriend(login.id, f.id, body, data.publishDate)
          )
          $scope.reloadPosts()
          $scope.post= {
            body: ""
          }

        (err) -> alert err.data
      )
)

app.controller('MainCtrl', MainCtrl = ($scope, $modal, $q, $location, UserGet, PostAdd, Friend, Network) ->
    parser = document.createElement('a');
    parser.href = window.location.href
    network = parser.pathname.replace(new RegExp("/", 'g'), "")

    $scope.menuShow = 'none'
    $scope.showAdmin = 'none';

    $scope.login = false
    api = new ApiManager(Friend, UserGet, PostAdd, $q)

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
)

app.controller('RegisterModalCtrl', RegisterModalCtrl = ($scope, UserAdd, UserGet, $modalInstance, $timeout) ->
    $scope.startGeneration = "none"
    $scope.user = {userName: "", userPassword: ""}
    $scope.submitPressed = false
    $scope.userExists='none'

    $scope.change = () ->
      UserGet.get(
        {
          userId: $scope.user.userName
          networkId: network
        }
        (data) ->
          $scope.userExists=''
        (err) ->
          $scope.userExists='none'
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
    .otherwise({
        redirectTo: '/'
      })
])