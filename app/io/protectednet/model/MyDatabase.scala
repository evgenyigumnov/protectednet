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
package io.protectednet.model

import com.websudos.phantom.connectors.{KeySpaceDef, ContactPoints}
import play.api.mvc.WebSocket.FrameFormatter


object Defaults {

  val hosts = Seq("localhost")

  val Connector = ContactPoints(hosts).keySpace("mykeyspace")

}

class MyDatabase(val keyspace: KeySpaceDef) extends com.websudos.phantom.db.DatabaseImpl(keyspace) {

  object users extends ConcreteUsers with keyspace.Connector

  object posts extends ConcretePosts with keyspace.Connector

  object networks extends ConcreteNetworks with keyspace.Connector

  object messages extends ConcreteMessages with keyspace.Connector

  object dialogs extends ConcreteDialogs with keyspace.Connector

}

object MyDatabase extends MyDatabase(Defaults.Connector)

object JsonFormats {

  import play.api.libs.json.Json

  implicit val bitcoinObjectFormat = Json.format[BitcointObject]
  implicit val userFormat = Json.format[User]
  implicit val postFormat = Json.format[Post]
  implicit val networkFormat = Json.format[Network]
  implicit val messagesFormat = Json.format[Message]
  implicit val dialogsFormat = Json.format[Dialog]
  implicit val changeEventFormat = Json.format[ChangeEvent]
  implicit val changeEventFrameFormatter = FrameFormatter.jsonFrame[ChangeEvent]

}