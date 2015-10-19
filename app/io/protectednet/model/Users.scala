package io.protectednet.model

// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/

import scala.concurrent.Future
import com.websudos.phantom.dsl._

case class User(id: String,
                privateKey: String,
                publicKey: String,
                networkId: String,
                isActive: Boolean
                 )

class Users extends CassandraTable[ConcreteUsers, User] {

  object id extends StringColumn(this) with PrimaryKey[String]

  object privateKey extends StringColumn(this)

  object publicKey extends StringColumn(this)

  object networkId extends StringColumn(this) with PartitionKey[String]

  object isActive extends BooleanColumn(this) with Index[Boolean]
//CREATE INDEX isactive ON users (isactive);


  def fromRow(row: Row): User = {
    User(
      id(row),
      privateKey(row),
      publicKey(row),
      networkId(row),
      isActive(row)
    )
  }
}

abstract class ConcreteUsers extends Users with RootConnector {

  def store(user: User): Future[ResultSet] = {
    insert.value(_.id, user.id).value(_.privateKey, user.privateKey)
      .value(_.publicKey, user.publicKey)
      .value(_.networkId, user.networkId)
      .value(_.isActive, user.isActive)
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }

  def getById(id: String, networkId: String): Future[Option[User]] = {
    select.where(_.id eqs id).and(_.networkId eqs networkId).one()
  }


  def getByNetworkIdAndActive(networkId: String,  active:Boolean): Future[List[User]] = {
    select.where(_.networkId eqs networkId).and(_.isActive eqs active).allowFiltering().fetch()
  }
  def getByNetworkId(networkId: String): Future[List[User]] = {
    select.where(_.networkId eqs networkId).allowFiltering().fetch()
  }

  def getAll(): Future[List[User]] = {
    select.fetch()
  }
}
