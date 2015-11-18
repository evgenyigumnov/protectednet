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


import akka.actor._
import io.protectednet.model.{MyDatabase, ChangeEvent}
import io.protectednet.model.JsonFormats._
import scala.concurrent.ExecutionContext.Implicits.global

object NotificationActor {
  def props(out: ActorRef, networkId: String, userId: String) = Props(new NotificationActor(out, networkId, userId))
}

class NotificationActor(out: ActorRef, networkId: String, userId: String) extends Actor {


  override def preStart() = context.system.eventStream.subscribe(self, classOf[ChangeEvent])

  override def postStop() = context.system.eventStream.unsubscribe(self, classOf[ChangeEvent])


  def receive = {
    case msg: ChangeEvent =>
      if (msg.networkId == networkId && (msg.fromId == "" || msg.toId == "")) {
        MyDatabase.dialogs.getByUserIdLimit(userId, networkId, 10).map(dialogs => {
          dialogs.find(dialog => dialog.unread).map(dialog => out ! (new ChangeEvent(networkId, dialog.friendId, userId)))
        })

      }
      else {
        if (msg.networkId == networkId && (msg.toId == userId || msg.toId == null))
          out ! (msg)
      }
  }
}