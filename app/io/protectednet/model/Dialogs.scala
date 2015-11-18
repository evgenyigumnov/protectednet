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


case class Dialog(
                    userId: String,
                    networkId: String,
                    friendId: String,
                    updated: Date,
                    unread: Boolean
                    )


class Dialogs extends CassandraTable[ConcreteDialogs, Dialog] {

  object userId extends StringColumn(this) with PartitionKey[String]
  object networkId extends StringColumn(this) with PartitionKey[String]
  object friendId extends StringColumn(this) with Index[String]
  object updated extends DateColumn(this)  with ClusteringOrder[Date] with Descending
  object unread extends BooleanColumn(this)


  def fromRow(row: Row): Dialog = {
    Dialog(
      userId(row),
      networkId(row),
      friendId(row),
      updated(row),
      unread(row)
    )
  }
}

abstract class ConcreteDialogs extends Dialogs with RootConnector {

  def store(dialog: Dialog): Future[ResultSet] = {
    insert.value(_.userId, dialog.userId)
      .value(_.friendId, dialog.friendId)
      .value(_.updated, dialog.updated)
      .value(_.networkId, dialog.networkId)
      .value(_.unread, dialog.unread)
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }

  def setReaded(userId: String, networkId: String, updated: Date): Future[ResultSet] = {
    update.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .and(_.updated eqs updated)
      .modify(_.unread setTo false)
      .future()
  }


  def getByUserId(userId: String, networkId: String): Future[List[Dialog]] = {
    select.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .orderBy(_.updated.desc)
      .fetch()
  }
  def getByUserIdLimit(userId: String, networkId: String, limit: Int): Future[List[Dialog]] = {
    select.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .orderBy(_.updated.desc).limit(limit)
      .fetch()
  }

  def getByUserIdFriendId(userId: String, networkId: String, friendId: String): Future[List[Dialog]] = {
    select.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .and(_.friendId eqs friendId)
      .fetch()
  }


  def deleteDialog(userId: String, networkId: String, updated: Date): Future[ResultSet] = {
    delete.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .and(_.updated eqs updated)
      .future()
  }
}
