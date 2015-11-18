/**
 *    Copyright (C) 2015 Evgeny Igumnov http://evgeny.igumnov.com igumnov@gmail.com
 *
 *    This program is free software: you can redistribute it and/or  modify
 *    it under the terms of the GNU Affero General Public License, version 3,
 *    as published by the Free Software Foundation.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU Affero General Public License for more details.
 *
 *    You should have received a copy of the GNU Affero General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package io.protectednet.controllers

import java.security.spec.{X509EncodedKeySpec, RSAPublicKeySpec}
import java.util.{Date}

import com.websudos.phantom.dsl._
import io.protectednet.model._
import play.api.Play.current
import play.api.i18n.{Messages, Lang}
import play.api.mvc._
import scala.concurrent.{Future}
import play.api.libs.json._
import io.protectednet.model.JsonFormats._
import scala.concurrent.ExecutionContext.Implicits.global


class MessagesController extends Controller {

  def addMessage(signature: String) = Action.async(parse.json) {
    request =>
      request.body.validate[Message].map {
        message => {
          MyDatabase.users.getById(message.authorId, message.networkId).flatMap(u => {
            if (Utils.checkSign(u.get.publicKey, signature, message.body) && u.get.isActive) {
              if (message.userId.equals(message.authorId)) {
                val newMessage = new Message(message.userId, message.authorId, message.friendId, message.body, new Date(),
                  message.networkId, message.cipher, message.imageBody, message.fileBody)
                MyDatabase.messages.store(newMessage).flatMap(r => if (r.wasApplied) {
                  MyDatabase.dialogs.getByUserIdFriendId(message.userId, message.networkId, message.friendId).flatMap(dialogs => {
                    dialogs.foreach(dialog => MyDatabase.dialogs.deleteDialog(dialog.userId, dialog.networkId, dialog.updated))
                    val dialog = new Dialog(newMessage.userId, newMessage.networkId, newMessage.friendId, newMessage.publishDate, false)
                    MyDatabase.dialogs.store(dialog).map(r => if (r.wasApplied()) {
                      Ok(Json.toJson(newMessage))
                    } else {
                      BadRequest("Err")
                    })
                  })
                } else {
                  Future.successful(BadRequest("Err"))
                })
              } else {
                MyDatabase.users.getById(message.userId, message.networkId).flatMap(r => if (r.isDefined) {
                  if (r.get.isActive) {
                    MyDatabase.messages.store(message).flatMap(r => if (r.wasApplied) {
                      MyDatabase.dialogs.getByUserIdFriendId(message.userId, message.networkId, message.authorId).flatMap(dialogs => {
                        dialogs.foreach(dialog => MyDatabase.dialogs.deleteDialog(dialog.userId, dialog.networkId, dialog.updated))
                        val dialog = new Dialog(message.userId, message.networkId, message.authorId, message.publishDate, true)
                        MyDatabase.dialogs.store(dialog).map(r => if (r.wasApplied()) {
                          Utils.publish(message.networkId, message.authorId, message.userId)
                          Ok(Json.toJson(message))
                        } else {
                          BadRequest("Err")
                        })
                      })
                    } else {
                      Future.successful(BadRequest("Err"))
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


  def findMessages(userId: String, networkId: String, friendId: String, signature: String, fromDate: Long) = Action.async {
    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(Utils.selectLang(request)), play.api.Play.current)


      MyDatabase.networks.getById(networkId).flatMap(network => if (network.isDefined) {
        if (network.get.blockDate.getTime > (new Date).getTime) {

          MyDatabase.users.getById(userId, networkId).flatMap(u => {
            if (Utils.checkSign(u.get.publicKey, signature, "messages")) {
              if (fromDate != 0) {
                import com.websudos.phantom.dsl._
                val fd = new Date(fromDate)
                val messages = MyDatabase.messages.getByUserIdFriendIdAndFromDate(userId, networkId, friendId, fd).map(message => {
                  val a = message.map(msg => {
                    val image = if (msg.imageBody != "") "image"
                    else ""
                    val file = if (msg.fileBody != "") "file"
                    else ""
                    new Message(msg.userId, msg.authorId, msg.friendId, msg.body, msg.publishDate, msg.networkId, msg.cipher, image, file)
                  })
                  Json.toJson(a)
                })
                messages.map { post =>
                  Ok(Json.toJson(post))
                }
              } else {
                val messages = MyDatabase.messages.getByUserIdFriendId(userId, friendId, networkId).map(message => {
                  val a = message.map(msg => {
                    val image = if (msg.imageBody != "") "image"
                    else ""
                    val file = if (msg.fileBody != "") "file"
                    else ""
                    new Message(msg.userId, msg.authorId, msg.friendId, msg.body, msg.publishDate, msg.networkId, msg.cipher, image, file)
                  })
                  Json.toJson(a)
                })

                MyDatabase.dialogs.getByUserIdFriendId(userId, networkId, friendId).map(dialogs => {
                  dialogs.foreach(dialog => MyDatabase.dialogs.setReaded(userId, networkId, dialog.updated))
                })


                messages.map { post =>
                  Ok(Json.toJson(post))
                }
              }

            } else {
              Future.successful(BadRequest("Err"))
            }
          })
        } else {
          Future.successful(BadRequest(messages.apply("expired.message")))
        }
      } else {
        Future.successful(BadRequest("Err"))
      })

  }

  def findDialogs(userId: String, networkId: String, signature: String) = Action.async {
    MyDatabase.users.getById(userId, networkId).flatMap(u => {
      if (Utils.checkSign(u.get.publicKey, signature, "dialogs")) {
        val dialogs = MyDatabase.dialogs.getByUserId(userId, networkId)
        dialogs.map { d =>
          Ok(Json.toJson(d))
        }
      } else {
        Future.successful(BadRequest("Err"))
      }
    })
  }


  def findMessageImage(userId: String, friendId: String, publishDate: Long, networkId: String, signature: String) = Action.async {

    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(Utils.selectLang(request)), play.api.Play.current)

      MyDatabase.users.getById(userId, networkId).flatMap(u => {
        if (Utils.checkSign(u.get.publicKey, signature, "image")) {
          MyDatabase.messages.getByUserIdFriendIdPublishDate(userId, friendId, new Date(publishDate), networkId).map(p => {
            if (p.isDefined) {
              val message = p.get
              val imagePost = new Message(message.userId, message.authorId, message.friendId, "", message.publishDate, message.networkId, message.cipher, message.imageBody, "")
              Ok(Json.toJson(imagePost))
            } else {
              BadRequest("Err")
            }
          })
        } else {
          Future.successful(BadRequest("Err"))

        }
      })
  }


  def findMessageFile(userId: String, friendId: String, publishDate: Long, networkId: String, signature: String) = Action.async {

    request =>
      val messages: Messages = play.api.i18n.Messages.Implicits.applicationMessages(
        Lang(Utils.selectLang(request)), play.api.Play.current)

      MyDatabase.users.getById(userId, networkId).flatMap(u => {
        if (Utils.checkSign(u.get.publicKey, signature, "file")) {
          MyDatabase.messages.getByUserIdFriendIdPublishDate(userId, friendId, new Date(publishDate), networkId).map(p => {
            if (p.isDefined) {
              val message = p.get
              val filePost = new Message(message.userId, message.authorId, message.friendId, "", message.publishDate, message.networkId, message.cipher, "", message.fileBody)
              Ok(Json.toJson(filePost))
            } else {
              BadRequest("Err")
            }
          })
        } else {
          Future.successful(BadRequest("Err"))

        }
      })
  }

  def socket(networkId: String, userId: String, sign: String) = WebSocket.tryAcceptWithActor[ChangeEvent, ChangeEvent] { request =>
    MyDatabase.users.getById(userId, networkId).map(u => {
      if (Utils.checkSign(u.get.publicKey, sign, "notifications"))
        Right(NotificationActor.props(_, networkId, userId))
      else
        Left(Forbidden)
    })
  }

}
