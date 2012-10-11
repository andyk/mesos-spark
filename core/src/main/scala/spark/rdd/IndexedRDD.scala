package spark.rdd

import spark.OneToOneDependency
import spark.RDD
import spark.Split
import java.util

class IndexedRDD[K, V](prev: RDD[(K,V)]) extends RDD[collection.mutable.Map[K,V]](prev.context) {
  override def splits = prev.splits
  override val dependencies = List(new OneToOneDependency(prev))
  override def compute(split: Split): Iterator[collection.mutable.Map[K,V]] = {
    val newMap = collection.mutable.Map[K,V]()
    prev.iterator(split).foreach{case (k: K,v: V) =>
      newMap(k) = v
    }
    Iterator(newMap)
  }
  def get(k: K): Option[V] = {
    map(_.get(k)).collect().reduce((x: Option[V], y: Option[V]) => {
      x match {
        case Some(foo) => return x
        case _ => return y
      }
    })
  }
}