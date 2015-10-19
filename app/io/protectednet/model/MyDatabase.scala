package io.protectednet.model
// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/

import com.websudos.phantom.dsl._
import com.websudos.phantom.connectors.{KeySpaceDef, ContactPoints}


object Defaults {

  val hosts = Seq("localhost")

  val Connector = ContactPoints(hosts).keySpace("mykeyspace")

}


class MyDatabase(val keyspace: KeySpaceDef) extends com.websudos.phantom.db.DatabaseImpl(keyspace) {
  object users extends ConcreteUsers with keyspace.Connector
  object posts extends ConcretePosts with keyspace.Connector
  object networks extends ConcreteNetworks with keyspace.Connector

}

object MyDatabase extends MyDatabase(Defaults.Connector)

object JsonFormats {
  import play.api.libs.json.Json
  implicit val userFormat = Json.format[User]
  implicit val postFormat = Json.format[Post]
  implicit val networkFormat = Json.format[Network]
}