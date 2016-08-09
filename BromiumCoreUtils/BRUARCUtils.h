//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#ifndef BRUARCUtils_h
#define BRUARCUtils_h

/**
 * weakifySelf/strongifySelf are inspired by RAC weakify/strongify.
 * If you are familiar with those, `BRU_weakify(self)` is equivalent to `@weakify(self)`.;
 * Same for strongify.
 *
 * Usage:
 *      Before a block of code that needs weak reference to self add:
 *          BRU_weakify(self);
 *      This replaces the usual `weakSelf` declaration and as such only needs to be
 *      done once in a given code block.
 *      Inside of the block that wants to use weak reference add:
 *          BRU_strongify(self);
 *      and use `self` instead of the usual `strongSelf`.
 *
 */

#define BRU_weakify(_var) /*
*/    __weak __typeof__(_var) _weak ## _var = (_var)

#define BRU_strongify(_var) /*
*/    _Pragma("clang diagnostic push"); /*
*/    _Pragma("clang diagnostic ignored \"-Wshadow\""); /*
*/    __strong __typeof__(_var) (_var) = _weak ## _var; /*
*/    _Pragma("clang diagnostic pop")

#define BRU_unavailable(_var) /*
*/    _Pragma("clang diagnostic push"); /*
*/    _Pragma("clang diagnostic ignored \"-Wshadow\""); /*
*/    _Pragma("clang diagnostic ignored \"-Wunused-variable\"") /*
*/    _Pragma("clang diagnostic ignored \"-Wgnu\"") /*
*/    _Pragma("clang diagnostic ignored \"-Wc++-compat\"") /*
*/    struct {} *(_var) = NULL; /*
*/    _Pragma("clang diagnostic pop");

#endif /* BRUARCUtils_h */
