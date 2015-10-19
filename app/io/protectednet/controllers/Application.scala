package io.protectednet.controllers

// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/


import java.io.File
import java.security.{Signature, KeyFactory}
import java.security.spec.{X509EncodedKeySpec, RSAPublicKeySpec}
import java.util.{UUID, Date}

import com.websudos.phantom.dsl._
import io.protectednet.model._
import org.joda.time.DateTime
import play.api.Play
import play.api.Play.current
import play.api.i18n.{Messages, Lang}
import play.api.mvc._
import sun.security.util.DerValue
import scala.concurrent.{Future, Await}
import play.api.libs.json._
import io.protectednet.model.JsonFormats._
import scala.concurrent.ExecutionContext.Implicits.global

import java.nio.charset.StandardCharsets
import java.util.Base64


class Application extends Controller {


  private def selectLang(request: RequestHeader, lang: String = "default"): String = {
    if (lang == "default") {
      val cookieLang = request.cookies.get("lang")
      if (cookieLang.isDefined) cookieLang.get.value
      else "en"
    } else lang
  }

  def indexEmpty(lang: String) = Action {

    request =>
      val langSetup: String = selectLang(request, lang)

      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(langSetup), play.api.Play.current)
      Ok({
        val javascripts = {
          Option(Play.getFile("app/assets")).
            filter(_.exists).
            map(findScripts).
            getOrElse(Nil)
        }
        views.html.start(javascripts)
      }).withCookies(Cookie("lang", langSetup))
  }

  def index(network: String, lang: String) = Action {

    request =>
      val langSetup: String = selectLang(request, lang)

      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(langSetup), play.api.Play.current)

      Ok({
        val javascripts = {
          Option(Play.getFile("app/assets")).
            filter(_.exists).
            map(findScripts).
            getOrElse(Nil)
        }

        views.html.main(network, javascripts)
      }).withCookies(Cookie("lang", langSetup))
  }


  def register = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.register())
  }

  def posts = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.posts())
  }


  def messages = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.messages())
  }

  def friends = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.friends())
  }


  def redirect = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.redirect())
  }

  def admin = Action {

    request =>
      implicit val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)

      Ok(views.html.admin())
  }

  private def findScripts(base: File): Seq[String] = {
    val baseUri = base.toURI
    directoryFlatMap(base, scriptMapper).
      map(f => baseUri.relativize(f.toURI).getPath)
  }

  private def directoryFlatMap[A](in: File, fileFun: File => Option[A]): Seq[A] = {
    in.listFiles.flatMap {
      case f if f.isDirectory => directoryFlatMap(f, fileFun)
      case f if f.isFile => fileFun(f)
    }
  }

  private def scriptMapper(file: File): Option[File] = {
    val name = file.getName
    if (name.endsWith(".js")) Some(file)
    else if (name.endsWith(".coffee")) Some(new File(file.getParent, name.dropRight(6) + "js"))
    else None
  }


  def getMessage(id: String) = Action {
    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)
      Ok(messages.apply(id))
  }

  def findUser(id: String, networkId: String) = Action.async {
    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)
      MyDatabase.users.getById(id, networkId).map(u => {
        if (u.isDefined) {
          Ok(Json.toJson(u))
        } else {
          BadRequest(messages.apply("user.absent"))
        }
      })
  }

  def findNetwork(networkId: String) = Action.async {
    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(selectLang(request)), play.api.Play.current)
      MyDatabase.networks.getById(networkId).map(n => {
        if (n.isDefined) {
          Ok(Json.toJson(n))
        } else {
          BadRequest(messages.apply("network.absent"))
        }
      })
  }

  def updateUser(signature: String, networkId: String) = Action.async(parse.json) {
    request =>
      request.body.validate[User].map {
        user => {
          val network = MyDatabase.networks.getById(user.networkId)
          network.flatMap(n => {
            if (n.isDefined) {
              MyDatabase.users.getById(n.get.adminId, user.networkId).flatMap(a => {
                if (a.isDefined) {
                  val sign = Base64.getDecoder.decode(signature)
                  val publicKeyDer = Base64.getDecoder.decode(a.get.publicKey)
                  val spec = new X509EncodedKeySpec(publicKeyDer)
                  val kf = KeyFactory.getInstance("RSA")
                  val publicKey = kf.generatePublic(spec)
                  val signatureTest = Signature.getInstance("SHA1withRSA")
                  signatureTest.initVerify(publicKey)
                  signatureTest.update(user.id.getBytes("utf-8"))
                  if (signatureTest.verify(sign)
                    && a.get.networkId == user.networkId
                    && !(a.get.id == user.id && !user.isActive)
                  ) {
                    MyDatabase.users.store(user).map(r => if (r.wasApplied) {
                      Ok(Json.toJson(user))
                    } else {
                      BadRequest("Err")
                    })
                  } else {
                    Future.successful(BadRequest("Err"))
                  }
                } else {
                  Future.successful(BadRequest("Err"))
                }
              })


            } else {

              Future.successful(BadRequest("Err"))

            }
          })

        }

      }.getOrElse(Future.successful(BadRequest("invalid json")))

  }

  def addUser(createNetwork: Boolean) = Action.async(parse.json) {
    request =>
      request.body.validate[User].map {
        if (createNetwork) {
          user => {
            val network = MyDatabase.networks.getById(user.networkId)
            network.flatMap(a => {
              if (a.isDefined) {
                Future.successful(BadRequest("Err"))
              } else {
                val net = new Network(user.networkId, user.id)
                MyDatabase.networks.store(net).flatMap(r => if (r.wasApplied) {
                  MyDatabase.users.store(user).map(r => if (r.wasApplied) {
                    Ok(Json.toJson(user))
                  } else {
                    BadRequest("Err")
                  })
                } else {
                  Future.successful(BadRequest("Err"))
                })

              }
            })

          }
        } else {
          user => {
            val network = MyDatabase.networks.getById(user.networkId)
            network.flatMap(a => {
              if (a.isEmpty) {
                Future.successful(BadRequest("Err"))
              } else {
                val u = MyDatabase.users.getById(user.id, user.networkId)
                u.flatMap(a => {
                  if (a.isDefined) {
                    Future.successful(BadRequest("Err"))
                  } else {
                    val newUser = new User(user.id, user.privateKey, user.publicKey, user.networkId, false)
                    MyDatabase.users.store(newUser).map(r => if (r.wasApplied) {
                      Ok(Json.toJson(user))
                    } else {
                      BadRequest("Err")
                    })
                  }
                })
              }
            })

          }

        }

      }.getOrElse(Future.successful(BadRequest("invalid json")))

  }

  def findPosts(userId: String, networkId: String, signature: String, fromDate: Long) = Action.async {
    MyDatabase.users.getById(userId, networkId).flatMap(u => {
      val sign = Base64.getDecoder.decode(java.net.URLDecoder.decode(signature, "UTF-8"))
      val publicKeyDer = Base64.getDecoder.decode(u.get.publicKey)
      val spec = new X509EncodedKeySpec(publicKeyDer)
      val kf = KeyFactory.getInstance("RSA")
      val publicKey = kf.generatePublic(spec)
      val signatureTest = Signature.getInstance("SHA1withRSA")
      signatureTest.initVerify(publicKey)
      signatureTest.update("posts".getBytes("utf-8"))
      if (signatureTest.verify(sign)) {
        if (fromDate != 0) {
          import com.websudos.phantom.dsl._
          val fd = new DateTime(fromDate)
          val posts = MyDatabase.posts.getByUserIdAndFromDate(userId, networkId, fd).map { a => Json.toJson(a) }
          posts.map { post =>
            Ok(Json.toJson(post))
          }
        } else {
          val posts = MyDatabase.posts.getByUserId(userId, networkId).map { a => Json.toJson(a) }
          posts.map { post =>
            Ok(Json.toJson(post))
          }

        }

      } else {
        Future.successful(BadRequest("Err"))
      }
    })
  }

  def addPost(signature: String) = Action.async(parse.json) {
    request =>
      request.body.validate[Post].map {
        post => {
          MyDatabase.users.getById(post.authorId, post.networkId).flatMap(u => {
            val sign = Base64.getDecoder.decode(java.net.URLDecoder.decode(signature, "UTF-8"))
            val publicKeyDer = Base64.getDecoder.decode(u.get.publicKey)
            val spec = new X509EncodedKeySpec(publicKeyDer)
            val kf = KeyFactory.getInstance("RSA")
            val publicKey = kf.generatePublic(spec)
            val signatureTest = Signature.getInstance("SHA1withRSA")
            signatureTest.initVerify(publicKey)
            signatureTest.update(post.body.getBytes("utf-8"))
            if (signatureTest.verify(sign) && u.get.isActive) {
              if (post.userId.equals(post.authorId)) {
                val newPost = new Post(post.userId, post.authorId, post.body, new DateTime(), post.networkId, post.cipher)
                MyDatabase.posts.store(newPost).map(r => if (r.wasApplied) {
                  Ok(Json.toJson(newPost))
                } else {
                  BadRequest("Err")
                })
              } else {
                MyDatabase.users.getById(post.userId, post.networkId).flatMap(r => if (r.isDefined) {
                  if (r.get.isActive) {
                    MyDatabase.posts.store(post).map(r => if (r.wasApplied) {
                      Ok(Json.toJson(post))
                    } else {
                      BadRequest("Err")
                    })
                  } else {
                    Future.successful(BadRequest("Err"))
                  }
                } else {
                  Future.successful(BadRequest("Err"))
                })
              }
            } else {
              Future.successful(BadRequest("Err"))
            }
          })
        }
      }.getOrElse(Future.successful(BadRequest("invalid json")))
  }


  def findFriends(userId: String, networkId: String, signature: String, all: Boolean) = Action.async {

    MyDatabase.users.getById(userId, networkId).flatMap(u => {
      val sign = Base64.getDecoder.decode(java.net.URLDecoder.decode(signature, "UTF-8"))
      val publicKeyDer = Base64.getDecoder.decode(u.get.publicKey)
      val spec = new X509EncodedKeySpec(publicKeyDer)
      val kf = KeyFactory.getInstance("RSA")
      val publicKey = kf.generatePublic(spec)
      val signatureTest = Signature.getInstance("SHA1withRSA")
      signatureTest.initVerify(publicKey)
      signatureTest.update("friends".getBytes("utf-8"))
      if (signatureTest.verify(sign) && u.get.isActive) {

        if (all) {
          val friends = MyDatabase.users.getByNetworkId(networkId).map { a => Json.toJson(a) }
          friends.map { friend =>
            Ok(Json.toJson(friend))
          }

        } else {
          val friends = MyDatabase.users.getByNetworkIdAndActive(networkId, true).map { a => Json.toJson(a) }
          friends.map { friend =>
            Ok(Json.toJson(friend))
          }
        }
      } else {
        Future.successful(BadRequest("Err"))
      }
    })
  }


}

