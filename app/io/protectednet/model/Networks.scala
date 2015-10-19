package io.protectednet.model
// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/



import scala.concurrent.Future
import com.websudos.phantom.dsl._

case class Network(id: String,
                adminId: String)

class Networks extends CassandraTable[ConcreteNetworks, Network] {

  object id extends StringColumn(this) with PartitionKey[String]

  object adminId extends StringColumn(this)


  def fromRow(row: Row): Network = {
    Network(
      id(row),
      adminId(row)
    )
  }
}

abstract class ConcreteNetworks extends Networks with RootConnector {

  def store(Network: Network): Future[ResultSet] = {
    insert.value(_.id, Network.id).value(_.adminId, Network.adminId)
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }

  def getById(id: String): Future[Option[Network]] = {
    select.where(_.id eqs id).one()
  }

  def getAll(): Future[List[Network]] = {
    select.fetch()
  }
}
