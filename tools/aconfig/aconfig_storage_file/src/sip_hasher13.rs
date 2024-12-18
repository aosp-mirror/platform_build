/*
 * Copyright (C) 2023 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//! An implementation of SipHash13

use std::cmp;
use std::mem;
use std::ptr;
use std::slice;

use std::hash::Hasher;

/// An implementation of SipHash 2-4.
///
#[derive(Debug, Clone, Default)]
pub struct SipHasher13 {
    k0: u64,
    k1: u64,
    length: usize, // how many bytes we've processed
    state: State,  // hash State
    tail: u64,     // unprocessed bytes le
    ntail: usize,  // how many bytes in tail are valid
}

#[derive(Debug, Clone, Copy, Default)]
#[repr(C)]
struct State {
    // v0, v2 and v1, v3 show up in pairs in the algorithm,
    // and simd implementations of SipHash will use vectors
    // of v02 and v13. By placing them in this order in the struct,
    // the compiler can pick up on just a few simd optimizations by itself.
    v0: u64,
    v2: u64,
    v1: u64,
    v3: u64,
}

macro_rules! compress {
    ($state:expr) => {{
        compress!($state.v0, $state.v1, $state.v2, $state.v3)
    }};
    ($v0:expr, $v1:expr, $v2:expr, $v3:expr) => {{
        $v0 = $v0.wrapping_add($v1);
        $v1 = $v1.rotate_left(13);
        $v1 ^= $v0;
        $v0 = $v0.rotate_left(32);
        $v2 = $v2.wrapping_add($v3);
        $v3 = $v3.rotate_left(16);
        $v3 ^= $v2;
        $v0 = $v0.wrapping_add($v3);
        $v3 = $v3.rotate_left(21);
        $v3 ^= $v0;
        $v2 = $v2.wrapping_add($v1);
        $v1 = $v1.rotate_left(17);
        $v1 ^= $v2;
        $v2 = $v2.rotate_left(32);
    }};
}

/// Load an integer of the desired type from a byte stream, in LE order. Uses
/// `copy_nonoverlapping` to let the compiler generate the most efficient way
/// to load it from a possibly unaligned address.
///
/// Unsafe because: unchecked indexing at i..i+size_of(int_ty)
macro_rules! load_int_le {
    ($buf:expr, $i:expr, $int_ty:ident) => {{
        debug_assert!($i + mem::size_of::<$int_ty>() <= $buf.len());
        let mut data = 0 as $int_ty;
        ptr::copy_nonoverlapping(
            $buf.get_unchecked($i),
            &mut data as *mut _ as *mut u8,
            mem::size_of::<$int_ty>(),
        );
        data.to_le()
    }};
}

/// Load an u64 using up to 7 bytes of a byte slice.
///
/// Unsafe because: unchecked indexing at start..start+len
#[inline]
unsafe fn u8to64_le(buf: &[u8], start: usize, len: usize) -> u64 {
    debug_assert!(len < 8);
    let mut i = 0; // current byte index (from LSB) in the output u64
    let mut out = 0;
    if i + 3 < len {
        out = load_int_le!(buf, start + i, u32) as u64;
        i += 4;
    }
    if i + 1 < len {
        out |= (load_int_le!(buf, start + i, u16) as u64) << (i * 8);
        i += 2
    }
    if i < len {
        out |= (*buf.get_unchecked(start + i) as u64) << (i * 8);
        i += 1;
    }
    debug_assert_eq!(i, len);
    out
}

impl SipHasher13 {
    /// Creates a new `SipHasher13` with the two initial keys set to 0.
    #[inline]
    pub fn new() -> SipHasher13 {
        SipHasher13::new_with_keys(0, 0)
    }

    /// Creates a `SipHasher13` that is keyed off the provided keys.
    #[inline]
    pub fn new_with_keys(key0: u64, key1: u64) -> SipHasher13 {
        let mut sip_hasher = SipHasher13 {
            k0: key0,
            k1: key1,
            length: 0,
            state: State { v0: 0, v1: 0, v2: 0, v3: 0 },
            tail: 0,
            ntail: 0,
        };
        sip_hasher.reset();
        sip_hasher
    }

    #[inline]
    fn c_rounds(state: &mut State) {
        compress!(state);
    }

    #[inline]
    fn d_rounds(state: &mut State) {
        compress!(state);
        compress!(state);
        compress!(state);
    }

    #[inline]
    fn reset(&mut self) {
        self.length = 0;
        self.state.v0 = self.k0 ^ 0x736f6d6570736575;
        self.state.v1 = self.k1 ^ 0x646f72616e646f6d;
        self.state.v2 = self.k0 ^ 0x6c7967656e657261;
        self.state.v3 = self.k1 ^ 0x7465646279746573;
        self.ntail = 0;
    }

    // Specialized write function that is only valid for buffers with len <= 8.
    // It's used to force inlining of write_u8 and write_usize, those would normally be inlined
    // except for composite types (that includes slices and str hashing because of delimiter).
    // Without this extra push the compiler is very reluctant to inline delimiter writes,
    // degrading performance substantially for the most common use cases.
    #[inline]
    fn short_write(&mut self, msg: &[u8]) {
        debug_assert!(msg.len() <= 8);
        let length = msg.len();
        self.length += length;

        let needed = 8 - self.ntail;
        let fill = cmp::min(length, needed);
        if fill == 8 {
            // safe to call since msg hasn't been loaded
            self.tail = unsafe { load_int_le!(msg, 0, u64) };
        } else {
            // safe to call since msg hasn't been loaded, and fill <= msg.len()
            self.tail |= unsafe { u8to64_le(msg, 0, fill) } << (8 * self.ntail);
            if length < needed {
                self.ntail += length;
                return;
            }
        }
        self.state.v3 ^= self.tail;
        Self::c_rounds(&mut self.state);
        self.state.v0 ^= self.tail;

        // Buffered tail is now flushed, process new input.
        self.ntail = length - needed;
        // safe to call since number of `needed` bytes has been loaded
        // and self.ntail + needed == msg.len()
        self.tail = unsafe { u8to64_le(msg, needed, self.ntail) };
    }
}

impl Hasher for SipHasher13 {
    // see short_write comment for explanation
    #[inline]
    fn write_usize(&mut self, i: usize) {
        // safe to call, since convert the pointer to u8
        let bytes = unsafe {
            slice::from_raw_parts(&i as *const usize as *const u8, mem::size_of::<usize>())
        };
        self.short_write(bytes);
    }

    // see short_write comment for explanation
    #[inline]
    fn write_u8(&mut self, i: u8) {
        self.short_write(&[i]);
    }

    #[inline]
    fn write(&mut self, msg: &[u8]) {
        let length = msg.len();
        self.length += length;

        let mut needed = 0;

        // loading unprocessed byte from last write
        if self.ntail != 0 {
            needed = 8 - self.ntail;
            // safe to call, since msg hasn't been processed
            // and cmp::min(length, needed) < 8
            self.tail |= unsafe { u8to64_le(msg, 0, cmp::min(length, needed)) } << 8 * self.ntail;
            if length < needed {
                self.ntail += length;
                return;
            } else {
                self.state.v3 ^= self.tail;
                Self::c_rounds(&mut self.state);
                self.state.v0 ^= self.tail;
                self.ntail = 0;
            }
        }

        // Buffered tail is now flushed, process new input.
        let len = length - needed;
        let left = len & 0x7;

        let mut i = needed;
        while i < len - left {
            // safe to call since if i < len - left, it means msg has at least 1 byte to load
            let mi = unsafe { load_int_le!(msg, i, u64) };

            self.state.v3 ^= mi;
            Self::c_rounds(&mut self.state);
            self.state.v0 ^= mi;

            i += 8;
        }

        // safe to call since if left == 0, since this call will load nothing
        // if left > 0, it means there are number of `left` bytes in msg
        self.tail = unsafe { u8to64_le(msg, i, left) };
        self.ntail = left;
    }

    #[inline]
    fn finish(&self) -> u64 {
        let mut state = self.state;

        let b: u64 = ((self.length as u64 & 0xff) << 56) | self.tail;

        state.v3 ^= b;
        Self::c_rounds(&mut state);
        state.v0 ^= b;

        state.v2 ^= 0xff;
        Self::d_rounds(&mut state);

        state.v0 ^ state.v1 ^ state.v2 ^ state.v3
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use std::hash::{Hash, Hasher};
    use std::string::String;

    #[test]
    // this test point locks down the value list serialization
    fn test_sip_hash13_string_hash() {
        let mut sip_hash13 = SipHasher13::new();
        let test_str1 = String::from("com.google.android.test");
        test_str1.hash(&mut sip_hash13);
        assert_eq!(17898838669067067585, sip_hash13.finish());

        let test_str2 = String::from("adfadfadf adfafadadf 1231241241");
        test_str2.hash(&mut sip_hash13);
        assert_eq!(13543518987672889310, sip_hash13.finish());
    }

    #[test]
    fn test_sip_hash13_write() {
        let mut sip_hash13 = SipHasher13::new();
        let test_str1 = String::from("com.google.android.test");
        sip_hash13.write(test_str1.as_bytes());
        sip_hash13.write_u8(0xff);
        assert_eq!(17898838669067067585, sip_hash13.finish());

        let mut sip_hash132 = SipHasher13::new();
        let test_str1 = String::from("com.google.android.test");
        sip_hash132.write(test_str1.as_bytes());
        assert_eq!(9685440969685209025, sip_hash132.finish());
        sip_hash132.write(test_str1.as_bytes());
        assert_eq!(6719694176662736568, sip_hash132.finish());

        let mut sip_hash133 = SipHasher13::new();
        let test_str2 = String::from("abcdefg");
        test_str2.hash(&mut sip_hash133);
        assert_eq!(2492161047327640297, sip_hash133.finish());

        let mut sip_hash134 = SipHasher13::new();
        let test_str3 = String::from("abcdefgh");
        test_str3.hash(&mut sip_hash134);
        assert_eq!(6689927370435554326, sip_hash134.finish());
    }

    #[test]
    fn test_sip_hash13_write_short() {
        let mut sip_hash13 = SipHasher13::new();
        sip_hash13.write_u8(0x61);
        assert_eq!(4644417185603328019, sip_hash13.finish());
    }
}
