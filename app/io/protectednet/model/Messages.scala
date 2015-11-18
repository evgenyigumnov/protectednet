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


case class Message(
                    userId: String,
                    authorId: String,
                    friendId: String,
                    body: String,
                    publishDate: Date,
                    networkId: String,
                    cipher: String,
                    imageBody: String,
                    fileBody: String
                    )


class Messages extends CassandraTable[ConcreteMessages, Message] {

  object userId extends StringColumn(this) with PartitionKey[String]

  object authorId extends StringColumn(this)


  object friendId extends StringColumn(this) with PartitionKey[String]


  object isRead extends BooleanColumn(this)



  object body extends StringColumn(this)

  object imageBody extends StringColumn(this)

  object fileBody extends StringColumn(this)


  object cipher extends StringColumn(this)

  object publishDate extends DateColumn(this) with ClusteringOrder[Date] with Descending

  object networkId extends StringColumn(this) with PartitionKey[String]


  def fromRow(row: Row): Message = {
    Message(
      userId(row),
      authorId(row),
      friendId(row),
      body(row),
      publishDate(row),
      networkId(row),
      cipher(row),
      imageBody(row),
      fileBody(row)
    )
  }
}

abstract class ConcreteMessages extends Messages with RootConnector {

  def store(message: Message): Future[ResultSet] = {
    insert.value(_.userId, message.userId)
      .value(_.authorId, message.authorId)
      .value(_.friendId, message.friendId)
      .value(_.body, message.body)
      .value(_.publishDate, message.publishDate)
      .value(_.networkId, message.networkId)
      .value(_.cipher, message.cipher)
      .value(_.imageBody, message.imageBody)
      .value(_.fileBody, message.fileBody)
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }


  def getByUserIdFriendIdPublishDate(userId: String, friendId: String, publishDate: Date, networkId: String) : Future[Option[Message]] = {
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).and(_.publishDate eqs publishDate).and(_.friendId eqs friendId).one()
  }

  def getByUserIdFriendId(userId: String, friendId: String, networkId: String): Future[List[Message]] = {
    select.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .and(_.friendId eqs friendId)
      .orderBy(_.publishDate.desc)
      .limit(10)
      .fetch()
  }

  def getByUserIdFriendIdAndFromDate(userId: String, networkId: String, friendId: String,  fromDate: Date): Future[List[Message]] = {
    select.where(_.userId eqs userId)
      .and(_.networkId eqs networkId)
      .and(_.friendId eqs friendId)
      .orderBy(_.publishDate.desc)
      .and(_.publishDate lt fromDate)
      .limit(10)
      .fetch()
  }
}
