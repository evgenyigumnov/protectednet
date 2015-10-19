// # Author Evgeny Igumnov igumnov@gmail.com Under GPL v2 http://www.gnu.org/licenses/

import com.websudos.phantom.connectors.KeySpace
import io.protectednet.model.{Defaults, MyDatabase}
import play.api._

import scala.concurrent.Await
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._

object Global extends GlobalSettings {
  override def onStart(app: Application) {
    println("Init database start")
    implicit val session = Defaults.Connector.session
    implicit val keySpace = KeySpace("mykeyspace")
    Await.result(MyDatabase.autocreate.future(), 1000.seconds)
    println("Init database end")
  }


}