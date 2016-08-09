//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#ifndef BRUDispatchUtils_h
#define BRUDispatchUtils_h

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <dispatch/dispatch.h>
#import <Foundation/NSException.h>

/**
 * This function must return a pointer that uniquely identifies the queue `q`. The caller must never dereference
 * that pointer, it is also not auto-nilled.
 */
static inline void * __nullable _bru_unretained_identifying_pointer_for_queue(__nonnull dispatch_queue_t q)
{
    void *q_ptr = NULL;
    assert(sizeof(dispatch_queue_t) == sizeof(void *));
    /* Nasty trick to get an unretained pointer to `q`. That's necessary because dispatch_queue_ts are no fully
     compliant Objective C objects, therefore a bridged cast does not work. */
    memcpy(&q_ptr, (void *)&q, sizeof(dispatch_queue_t));
    return q_ptr;
}

/**
 * Returns whether the passed queue is marked (ie created with `bru_dispatch_queue_create`) and has the same marker
 * as the passed in queue `q`. Passing a queue that wasn't created with `bru_dispatch_queue_create` is undefined
 * behaviour however it should work safely in the `BRU_ASSERT_ON_QUEUE` and `BRU_ASSERT_OFF_QUEUE` macros.
 *
 * @note Should not be used outside of this file except for testing/debugging purposes.
 *
 * @param q The queue to check
 * @return Whether we currently on that queue or not
 */
static inline BOOL _bru_is_on_queue(__nonnull dispatch_queue_t q)
{
    NSCParameterAssert(q);
    const void *key_q_id = _bru_unretained_identifying_pointer_for_queue(q);
    if (!key_q_id) {
        return NO;
    } else {
        void *ctx_q = dispatch_queue_get_specific(q, key_q_id);
        if (!ctx_q) {
            // passed queue was not created with bru_dispatch_queue_create
            // this is supported as well
            ctx_q = (void *)0x1;
            dispatch_queue_set_specific(q, key_q_id, ctx_q, NULL);
        }
        const void *ctx_me = dispatch_get_specific(key_q_id);
        return ctx_q && ctx_q == ctx_me;
    }
}

/**
 * Bromium wrapper for `bru_dispatch_queue_create`. Additionally decoreates the queues with a Bromium specific
 * queue identifier in order to recognize it in `BRU_ASSERT_ON_QUEUE`.
 */
static inline __nonnull dispatch_queue_t bru_dispatch_queue_create(const char * __nullable label,
                                                                   __nullable dispatch_queue_attr_t attr)
{
    NSCParameterAssert(label);
    dispatch_queue_t q = dispatch_queue_create(label, attr);
    const void *queueIDKey = _bru_unretained_identifying_pointer_for_queue(q);
    void *queueIDValue = strdup(label);
    dispatch_queue_set_specific(q, queueIDKey, queueIDValue, free);

    // also set queue name as specific to be able to find out name of the current queue later
    void *queueNameStoredAsSpecific = strdup(label);
    dispatch_queue_set_specific(q, (void *)13, queueNameStoredAsSpecific, free);

    return q;
}

#ifndef BRU_DONT_MARK_DISPATCH_QUEUE_CREATE_AS_DEPRECATED
__attribute__((deprecated)) __nonnull dispatch_queue_t dispatch_queue_create(const char * __nullable label,
                                                                             __nullable dispatch_queue_attr_t attr);
#endif

#define BRU_ASSERT_ON_QUEUE(e) /*
*/do { /*
*/    BRUAssert((e), @"queue is nil"); /*
*/    BRUAssert(_bru_is_on_queue(e), @"running on wrong queue"); /*
*/} while (0)


#define BRU_ASSERT_OFF_QUEUE(e) /*
*/do { /*
*/    BRUAssert(!_bru_is_on_queue(e), @"running on wrong queue"); /*
*/} while (0)

/**
 * Dispatches a block on the given queue. If the caller is already running on that queue, we fail,
 * otherwise the block is dispatch(_sync)ed to that queue.
 *
 * @param queue The queue to execute on
 * @param block The block to run
 */
#define BRU_DISPATCH_SYNC_ASSERT_OFF_QUEUE(queue, block) /*
*/  BRU_ASSERT_OFF_QUEUE(queue); /*
*/  dispatch_sync(queue, block)

#endif /* BRUDispatchUtils_h */
