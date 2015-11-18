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


case class Post(
                 userId: String,
                 authorId: String,
                 body: String,
                 publishDate: Date,
                 networkId: String,
                 cipher: String,
                 imageBody: String,
                 fileBody: String
                 )


class Posts extends CassandraTable[ConcretePosts, Post] {

  object userId extends StringColumn(this) with PartitionKey[String]

  object authorId extends StringColumn(this) with Index[String]

  object body extends StringColumn(this)

  object imageBody extends StringColumn(this)

  object fileBody extends StringColumn(this)


  object cipher extends StringColumn(this)

  object publishDate extends DateColumn(this) with ClusteringOrder[Date] with Descending

  object networkId extends StringColumn(this) with PartitionKey[String]


  def fromRow(row: Row): Post = {
    Post(
      userId(row),
      authorId(row),
      body(row),
      publishDate(row),
      networkId(row),
      cipher(row),
      imageBody(row),
      fileBody(row)
    )
  }
}

abstract class ConcretePosts extends Posts with RootConnector {

  def store(post: Post): Future[ResultSet] = {
    insert.value(_.userId, post.userId)
      .value(_.authorId, post.authorId)
      .value(_.body, post.body)
      .value(_.publishDate, post.publishDate)
      .value(_.networkId, post.networkId)
      .value(_.cipher, post.cipher)
      .value(_.imageBody, post.imageBody)
      .value(_.fileBody, post.fileBody)
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }

  def getByUserIdAuthorIdPublishDate(userId: String, authorId: String, publishDate: Date, networkId: String): Future[Option[Post]] = {
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).and(_.publishDate eqs publishDate).and(_.authorId eqs authorId).one()
  }

  def getByUserId(userId: String, networkId: String): Future[List[Post]] = {
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).orderBy(_.publishDate.desc)
      .limit(10)
      .fetch()
  }

  def getByUserIdAndFromDate(userId: String, networkId: String, fromDate: Date): Future[List[Post]] = {
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).orderBy(_.publishDate.desc)
      .and(_.publishDate lt fromDate)
      .limit(10)
      .fetch()
  }
}
