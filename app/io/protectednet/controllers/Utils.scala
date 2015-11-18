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
package io.protectednet.controllers

import java.security.{Signature, KeyFactory}
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

import play.api.libs.concurrent.Akka
import play.api.mvc.RequestHeader
import akka.actor._
import io.protectednet.model.ChangeEvent

object Utils {
  def publish(networkId: String, fromId: String, toId:String) = {
    Akka.system(play.api.Play.current).eventStream.publish(new ChangeEvent(networkId,fromId, toId))
  }


  def checkSign(publicKeyStr:String, signature: String, message: String ): Boolean = {

    val signWithoutSpace = java.net.URLDecoder.decode(signature, "UTF-8").replace(" ", "+")
    val sign = Base64.getDecoder.decode(signWithoutSpace)
    val publicKeyDer = Base64.getDecoder.decode(publicKeyStr)
    val spec = new X509EncodedKeySpec(publicKeyDer)
    val kf = KeyFactory.getInstance("RSA")
    val publicKey = kf.generatePublic(spec)
    val signatureTest = Signature.getInstance("SHA256withRSA")
    signatureTest.initVerify(publicKey)
    signatureTest.update(message.getBytes("utf-8"))
    signatureTest.verify(sign)
  }

  def selectLang(request: RequestHeader, lang: String = "default"): String = {
    if (lang == "default") {
      val cookieLang = request.cookies.get("lang")
      if (cookieLang.isDefined) cookieLang.get.value
      else "en"
    } else lang
  }

}
