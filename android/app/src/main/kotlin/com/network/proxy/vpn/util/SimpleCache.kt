package com.network.proxy.vpn.util

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class SimpleCache<K, V>(
    private val maxSize: Int,
    private val expireAfterAccess: Long,
    private val timeUnit: TimeUnit
) {
    private val cache = ConcurrentHashMap<K, CacheEntry<V>>()

    companion object {
        private val EXECUTOR = Executors.newSingleThreadScheduledExecutor()
    }


    init {
        EXECUTOR.scheduleWithFixedDelay(
            { cleanUp() },
            expireAfterAccess,
            expireAfterAccess,
            timeUnit
        )
    }

    fun put(key: K, value: V) {
        if (cache.size >= maxSize) {
            cache.keys.iterator().next()?.let { cache.remove(it) }
        }
        cache[key] = CacheEntry(value, System.nanoTime())
    }

    fun get(key: K): V? {
        val entry = cache[key] ?: return null
        if (System.nanoTime() - entry.lastAccessTime > timeUnit.toNanos(expireAfterAccess)) {
            cache.remove(key)
            return null
        }

        entry.lastAccessTime = System.nanoTime()
        return entry.value
    }

    fun remove(key: K) {
        cache.remove(key)
    }

    fun clear() {
        cache.clear()
    }

    private fun cleanUp() {
        val now = System.nanoTime()
        val expirationTime = timeUnit.toNanos(expireAfterAccess)

        val iterator = cache.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (now - entry.value.lastAccessTime > expirationTime) {
                iterator.remove()
            }
        }
    }

    private data class CacheEntry<V>(val value: V, var lastAccessTime: Long)
}