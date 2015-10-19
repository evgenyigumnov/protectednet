package io.protectednet.model
// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/

import scala.concurrent.Future
import com.websudos.phantom.dsl._


case class Post(
                 userId: String,
                 authorId: String,
                 body: String,
                 publishDate: DateTime,
                 networkId: String,
                 cipher: String
                 )


class Posts extends CassandraTable[ConcretePosts, Post] {

  object userId extends StringColumn(this) with PartitionKey[String]

  object authorId extends StringColumn(this)

  object body extends StringColumn(this)

  object cipher extends StringColumn(this)

  object publishDate extends DateTimeColumn(this) with ClusteringOrder[DateTime] with Descending

  object networkId extends StringColumn(this) with PartitionKey[String]


  def fromRow(row: Row): Post = {
    Post(
      userId(row),
      authorId(row),
      body(row),
      publishDate(row),
      networkId(row),
      cipher(row)

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
      .consistencyLevel_=(ConsistencyLevel.ALL)
      .future()
  }
  def getByUserId(userId: String, networkId: String): Future[List[Post]] = {
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).orderBy(_.publishDate.desc)
      .limit(10)
      .fetch()
  }
  def getByUserIdAndFromDate(userId: String, networkId: String, fromDate: DateTime): Future[List[Post]] = {
    //println(fromDate)
    select.where(_.userId eqs userId).and(_.networkId eqs networkId).orderBy(_.publishDate.desc)
      .and(_.publishDate lt fromDate)
      .limit(10)
      .fetch()
  }
}
