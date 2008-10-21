#include <common.h>
#include <debug.h>
#include <rangesort.h>

#define PARALLEL_ARRAY_SIZE (5)

struct range_list_t {
    range_t *array;
#ifdef DEBUG
    int is_sorted;
#endif
    int array_length;
    int num_ranges;
};

range_list_t* init_range_list(void) {
    range_list_t *ranges = (range_list_t *)MALLOC(sizeof(range_list_t));

    ranges->array = (range_t *)MALLOC(PARALLEL_ARRAY_SIZE*sizeof(range_t));
    ranges->array_length = PARALLEL_ARRAY_SIZE;
    ranges->num_ranges = 0;
#ifdef DEBUG
    ranges->is_sorted = 0;
#endif
    return ranges; 
}

void destroy_range_list(range_list_t *ranges) {
    int idx;
    for (idx = 0; idx < ranges->num_ranges; idx++) {
        if (ranges->array[idx].user_dtor) {
            ASSERT(ranges->array[idx].user);
            ranges->array[idx].user_dtor(ranges->array[idx].user);
        }
    }
    FREE(ranges->array);
    FREE(ranges);
}

static inline int CONTAINS(range_t *container, range_t *contained) {
    return container->start <= contained->start && contained->length && 
    (container->start + container->length > 
     contained->start + contained->length);
}

static inline int IN_RANGE(range_t *range, GElf_Off point) {
    return 
    range->start <= point && 
    point < (range->start + range->length);
}

static inline int INTERSECT(range_t *left, range_t *right) {
    return 
    (IN_RANGE(left, right->start) && 
     IN_RANGE(right, left->start + left->length)) ||
    (IN_RANGE(right, left->start) && 
     IN_RANGE(left, right->start + right->length));
}

static int range_cmp_for_search(const void *l, const void *r) {
    range_t *left = (range_t *)l, *right = (range_t *)r;
    if (INTERSECT(left, right) ||
        CONTAINS(left, right) ||
        CONTAINS(right, left)) {
        return 0;
    }
    return left->start - right->start;
}

static inline void run_checks(const void *l, const void *r) {
    range_t *left = (range_t *)l, *right = (range_t *)r;
    if (CONTAINS(left, right)) {
        if (left->err_fn)
            left->err_fn(ERROR_CONTAINS, left, right);
        FAILIF(1, "Range sorting error: [%lld, %lld) contains [%lld, %lld)!\n",
               left->start, left->start + left->length,
               right->start, right->start + right->length);
    }
    if (CONTAINS(right, left)) {
        if (right->err_fn)
            right->err_fn(ERROR_CONTAINS, left, right);
        FAILIF(1, "Range sorting error: [%lld, %lld) contains [%lld, %lld)!\n",
               right->start, right->start + right->length,
               left->start, left->start + left->length);
    }
    if (INTERSECT(left, right)) {
        if (left->err_fn)
            left->err_fn(ERROR_OVERLAPS, left, right);
        FAILIF(1, "Range sorting error: [%lld, %lld)and [%lld, %lld) intersect!\n",
               left->start, left->start + left->length,
               right->start, right->start + right->length);
    }
}

static int range_cmp(const void *l, const void *r) {
    run_checks(l, r);
    range_t *left = (range_t *)l, *right = (range_t *)r;
    return left->start - right->start;
}

void add_unique_range_nosort(
                            range_list_t *ranges, 
                            GElf_Off start, 
                            GElf_Off length, 
                            void *user,
                            void (*err_fn)(range_error_t, range_t *, range_t *),
                            void (*user_dtor)(void * )) 
{
    if (ranges->num_ranges == ranges->array_length) {
        ranges->array_length += PARALLEL_ARRAY_SIZE;
        ranges->array = REALLOC(ranges->array, 
                                ranges->array_length*sizeof(range_t));
    }
    ranges->array[ranges->num_ranges].start  = start;
    ranges->array[ranges->num_ranges].length = length;
    ranges->array[ranges->num_ranges].user   = user;
    ranges->array[ranges->num_ranges].err_fn = err_fn;
    ranges->array[ranges->num_ranges].user_dtor = user_dtor;
    ranges->num_ranges++;
}

range_list_t *sort_ranges(range_list_t *ranges) {
    if (ranges->num_ranges > 1)
        qsort(ranges->array, ranges->num_ranges, sizeof(range_t), range_cmp);
    ranges->is_sorted = 1;
    return ranges;
}

range_t *find_range(range_list_t *ranges, GElf_Off value) {
#if 1
    int i;
    for (i = 0; i < ranges->num_ranges; i++) {
        if (ranges->array[i].start <= value && 
            value < ranges->array[i].start + ranges->array[i].length)
            return ranges->array + i;
    }
    return NULL;
#else
    ASSERT(ranges->is_sorted); /* The range list must be sorted */
    range_t lookup;
    lookup.start = value;
    lookup.length = 0;
    return 
    (range_t *)bsearch(&lookup, 
                       ranges->array, ranges->num_ranges, sizeof(range_t), 
                       range_cmp_for_search);
#endif
}

int get_num_ranges(const range_list_t *ranges)
{
    return ranges->num_ranges;
}

range_t *get_sorted_ranges(const range_list_t *ranges, int *num_ranges) {
    ASSERT(ranges->is_sorted); /* The range list must be sorted */
    if (num_ranges) {
        *num_ranges = ranges->num_ranges;
    }
    return ranges->array;
}

GElf_Off get_last_address(const range_list_t *ranges) {
    ASSERT(ranges->num_ranges);
    return 
    ranges->array[ranges->num_ranges-1].start +
    ranges->array[ranges->num_ranges-1].length;
}

static void handle_range_error(range_error_t err, 
                               range_t *left, range_t *right) {
    switch (err) {
    case ERROR_CONTAINS:
        ERROR("ERROR: section (%lld, %lld bytes) contains "
              "section (%lld, %lld bytes)\n",
              left->start, left->length,
              right->start, right->length);
        break;
    case ERROR_OVERLAPS:
        ERROR("ERROR: Section (%lld, %lld bytes) intersects "
              "section (%lld, %lld bytes)\n",
              left->start, left->length,
              right->start, right->length);
        break;
    default:
        ASSERT(!"Unknown range error code!");
    }

    FAILIF(1, "Range error.\n");
}

static void destroy_contiguous_range_info(void *user) {
    contiguous_range_info_t *info = (contiguous_range_info_t *)user;
    FREE(info->ranges);
    FREE(info);
}

static void handle_contiguous_range_error(range_error_t err, 
                                          range_t *left, 
                                          range_t *right)
{
    contiguous_range_info_t *left_data = 
        (contiguous_range_info_t *)left->user;
    ASSERT(left_data);
    contiguous_range_info_t *right_data = 
        (contiguous_range_info_t *)right->user;
    ASSERT(right_data);

    PRINT("Contiguous-range overlap error.  Printing contained ranges:\n");
    int cnt;
    PRINT("\tLeft ranges:\n");
    for (cnt = 0; cnt < left_data->num_ranges; cnt++) {
        PRINT("\t\t[%lld, %lld)\n",
              left_data->ranges[cnt].start,
              left_data->ranges[cnt].start + left_data->ranges[cnt].length);
    }
    PRINT("\tRight ranges:\n");
    for (cnt = 0; cnt < right_data->num_ranges; cnt++) {
        PRINT("\t\t[%lld, %lld)\n",
              right_data->ranges[cnt].start,
              right_data->ranges[cnt].start + right_data->ranges[cnt].length);
    }

    handle_range_error(err, left, right);
}

range_list_t* get_contiguous_ranges(const range_list_t *input)
{
    ASSERT(input);
    FAILIF(!input->is_sorted, 
           "get_contiguous_ranges(): input range list is not sorted!\n");

    range_list_t* ret = init_range_list();
    int num_ranges;
    range_t *ranges = get_sorted_ranges(input, &num_ranges);

    int end_idx = 0;
    while (end_idx < num_ranges) {
        int start_idx = end_idx++;
        int old_end_idx = start_idx;
        int total_length = ranges[start_idx].length;
        while (end_idx < num_ranges) {
            if (ranges[old_end_idx].start + ranges[old_end_idx].length !=
                ranges[end_idx].start)
                break;
            old_end_idx = end_idx++;
            total_length += ranges[old_end_idx].length;
        }

        contiguous_range_info_t *user = 
            (contiguous_range_info_t *)MALLOC(sizeof(contiguous_range_info_t));
        user->num_ranges = end_idx - start_idx;
        user->ranges = (range_t *)MALLOC(user->num_ranges * sizeof(range_t));
        int i;
        for (i = 0; i < end_idx - start_idx; i++)
            user->ranges[i] = ranges[start_idx + i];
        add_unique_range_nosort(ret, 
                                ranges[start_idx].start,
                                total_length,
                                user,
                                handle_contiguous_range_error,
                                destroy_contiguous_range_info);
    }

    return ret;
}

range_list_t* subtract_ranges(const range_list_t *r, const range_list_t *s)
{
    ASSERT(r);  ASSERT(r->is_sorted);
    ASSERT(s);  ASSERT(s->is_sorted);

    range_list_t *result = init_range_list();

    int r_num_ranges, r_idx;
    range_t *r_ranges = get_sorted_ranges(r, &r_num_ranges);
    ASSERT(r_ranges);

    int s_num_ranges, s_idx;
    range_t *s_ranges = get_sorted_ranges(s, &s_num_ranges);
    ASSERT(s_ranges);

    s_idx = 0;
    for (r_idx = 0; r_idx < r_num_ranges; r_idx++) {
        GElf_Off last_start = r_ranges[r_idx].start;
        for (; s_idx < s_num_ranges; s_idx++) {
            if (CONTAINS(&r_ranges[r_idx], &s_ranges[s_idx])) {
                if (last_start == 
                    r_ranges[r_idx].start + r_ranges[r_idx].length) {
                    break;
                }
                if (last_start == s_ranges[s_idx].start) {
                    last_start += s_ranges[s_idx].length;
                    continue;
                }
                INFO("Adding subtracted range [%lld, %lld)\n",
                     last_start,
                     s_ranges[s_idx].start);
                add_unique_range_nosort(
                    result, 
                    last_start,
                    s_ranges[s_idx].start - last_start,
                    NULL,
                    NULL,
                    NULL);
                last_start = s_ranges[s_idx].start + s_ranges[s_idx].length;
            } else {
                ASSERT(!INTERSECT(&r_ranges[r_idx], &s_ranges[s_idx]));
                break;
            }
        } /* while (s_idx < s_num_ranges) */
    } /* for (r_idx = 0; r_idx < r_num_ranges; r_idx++) */

    return result;
}


