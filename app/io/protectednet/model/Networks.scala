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

import java.util.Date

import scala.concurrent.Future
import com.websudos.phantom.dsl._

case class Network(id: String,
                   adminId: String,
                   blockDate: Date
                    )

class Networks extends CassandraTable[ConcreteNetworks, Network] {

  object id extends StringColumn(this) with PartitionKey[String]

  object adminId extends StringColumn(this)

  object blockDate extends DateColumn(this)

  def fromRow(row: Row): Network = {
    Network(
      id(row),
      adminId(row),
      blockDate(row)
    )
  }
}

abstract class ConcreteNetworks extends Networks with RootConnector {

  def store(network: Network): Future[ResultSet] = {
    insert.value(_.id, network.id)
      .value(_.adminId, network.adminId)
      .value(_.blockDate, network.blockDate)
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
