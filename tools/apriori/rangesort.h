#ifndef RANGESORT_H
#define RANGESORT_H

/* This implements a simple sorted list of non-overlapping ranges. */

#include <debug.h>
#include <common.h>
#include <gelf.h>

typedef enum range_error_t {
    ERROR_CONTAINS,
    ERROR_OVERLAPS
} range_error_t;

typedef struct range_t range_t;
struct range_t {
    GElf_Off start;
    GElf_Off length;
    void *user;
    void (*err_fn)(range_error_t, range_t *, range_t *);
    void (*user_dtor)(void *);
};

typedef struct range_list_t range_list_t;

range_list_t* init_range_list();
void destroy_range_list(range_list_t *);

/* Just adds a range to the list. We won't detect whether the range overlaps
   other ranges or contains them, or is contained by them, till we call 
   sort_ranges(). */
void add_unique_range_nosort(range_list_t *ranges, 
                             GElf_Off start, GElf_Off length, 
                             void *user,
                             void (*err_fn)(range_error_t, range_t *, range_t *),
                             void (*user_dtor)(void * ));

/* Sorts the ranges.  If there are overlapping ranges or ranges that contain
   other ranges, it will cause the program to exit with a FAIL. */
range_list_t* sort_ranges(range_list_t *ranges);
/* Find which range value falls in.  Return that range or NULL if value does
   not fall within any range. */
range_t *find_range(range_list_t *ranges, GElf_Off value);
int get_num_ranges(const range_list_t *ranges);
range_t *get_sorted_ranges(const range_list_t *ranges, int *num_ranges);
GElf_Off get_last_address(const range_list_t *ranges);

/* This returns a range_list_t handle that contains ranges composed of the 
   adjacent ranges of the input range list.  The user data of each range in 
   the range list is a structure of the type contiguous_range_info_t. 
   This structure contains an array of pointers to copies of the original 
   range_t structures comprising each new contiguous range, as well as the 
   length of that array.  

   NOTE: The input range must be sorted!

   NOTE: destroy_range_list() will take care of releasing the data that it
   allocates as a result of calling get_contiguous_ranges().  Do not free that
   data yourself.

   NOTE: the user data of the original range_t structures is simply copied, so 
   be careful handling it. You can destroy the range_list_t with 
   destroy_range_list() as usual.  On error, the function does not return--the 
   program terminates. 

   NOTE: The returned range is not sorted.  You must call sort_ranges() if you
   need to.
*/

typedef struct {
    int num_ranges;
    range_t *ranges;
} contiguous_range_info_t;

range_list_t* get_contiguous_ranges(const range_list_t *);

/* The function below takes in two range lists: r and s, and subtracts the 
   ranges in s from those in r.  For example, if r and s are as follows:

   r = { [0, 10) }
   s = { [3, 5), [7, 9) }

   Then r - s is { [0, 3), [5, 7), [9, 10) }

   NOTE: Both range lists must be sorted on input.  This is guarded by an 
         assertion.

   NOTE: Range s must contain ranges, which are fully contained by the span of
         range r (the span being the interval between the start of the lowest
         range in r, inclusive, and the end of the highest range in r, 
         exclusive).

   NOTE: In addition to the requirement above, range s must contain ranges, 
         each of which is a subrange of one of the ranges of r.

   NOTE: There is no user info associated with the resulting range. 

   NOTE: The resulting range is not sorted.

   Ther returned list must be destroyed with destroy_range_list().
*/

range_list_t* subtract_ranges(const range_list_t *r, const range_list_t *s);

#endif/*RANGESORT_H*/
