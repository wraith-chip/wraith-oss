#define LIMIT -999
//#define TRACE
#include <stdlib.h>
//#define NUM_THREAD 4

#define BLOCK_SIZE 16

////////////////////////////////////////////////////////////////////////////////
// declaration, forward
void main();

int maximum( int a,
		 int b,
		 int c){

	int k;
	if( a <= b )
		k = b;
	else
	  k = a;

	if( k <=c )
	return(c);
	else
	return(k);
}

int blosum62[24][24] = {
{ 4, -1, -2, -2,  0, -1, -1,  0, -2, -1, -1, -1, -1, -2, -1,  1,  0, -3, -2,  0, -2, -1,  0, -4},
{-1,  5,  0, -2, -3,  1,  0, -2,  0, -3, -2,  2, -1, -3, -2, -1, -1, -3, -2, -3, -1,  0, -1, -4},
{-2,  0,  6,  1, -3,  0,  0,  0,  1, -3, -3,  0, -2, -3, -2,  1,  0, -4, -2, -3,  3,  0, -1, -4},
{-2, -2,  1,  6, -3,  0,  2, -1, -1, -3, -4, -1, -3, -3, -1,  0, -1, -4, -3, -3,  4,  1, -1, -4},
{ 0, -3, -3, -3,  9, -3, -4, -3, -3, -1, -1, -3, -1, -2, -3, -1, -1, -2, -2, -1, -3, -3, -2, -4},
{-1,  1,  0,  0, -3,  5,  2, -2,  0, -3, -2,  1,  0, -3, -1,  0, -1, -2, -1, -2,  0,  3, -1, -4},
{-1,  0,  0,  2, -4,  2,  5, -2,  0, -3, -3,  1, -2, -3, -1,  0, -1, -3, -2, -2,  1,  4, -1, -4},
{ 0, -2,  0, -1, -3, -2, -2,  6, -2, -4, -4, -2, -3, -3, -2,  0, -2, -2, -3, -3, -1, -2, -1, -4},
{-2,  0,  1, -1, -3,  0,  0, -2,  8, -3, -3, -1, -2, -1, -2, -1, -2, -2,  2, -3,  0,  0, -1, -4},
{-1, -3, -3, -3, -1, -3, -3, -4, -3,  4,  2, -3,  1,  0, -3, -2, -1, -3, -1,  3, -3, -3, -1, -4},
{-1, -2, -3, -4, -1, -2, -3, -4, -3,  2,  4, -2,  2,  0, -3, -2, -1, -2, -1,  1, -4, -3, -1, -4},
{-1,  2,  0, -1, -3,  1,  1, -2, -1, -3, -2,  5, -1, -3, -1,  0, -1, -3, -2, -2,  0,  1, -1, -4},
{-1, -1, -2, -3, -1,  0, -2, -3, -2,  1,  2, -1,  5,  0, -2, -1, -1, -1, -1,  1, -3, -1, -1, -4},
{-2, -3, -3, -3, -2, -3, -3, -3, -1,  0,  0, -3,  0,  6, -4, -2, -2,  1,  3, -1, -3, -3, -1, -4},
{-1, -2, -2, -1, -3, -1, -1, -2, -2, -3, -3, -1, -2, -4,  7, -1, -1, -4, -3, -2, -2, -1, -2, -4},
{ 1, -1,  1,  0, -1,  0,  0,  0, -1, -2, -2,  0, -1, -2, -1,  4,  1, -3, -2, -2,  0,  0,  0, -4},
{ 0, -1,  0, -1, -1, -1, -1, -2, -2, -1, -1, -1, -1, -2, -1,  1,  5, -2, -2,  0, -1, -1,  0, -4},
{-3, -3, -4, -4, -2, -2, -3, -2, -2, -3, -2, -3, -1,  1, -4, -3, -2, 11,  2, -3, -4, -3, -2, -4},
{-2, -2, -2, -3, -2, -1, -2, -3,  2, -1, -1, -2, -1,  3, -3, -2, -2,  2,  7, -1, -3, -2, -1, -4},
{ 0, -3, -3, -3, -1, -2, -2, -3, -3,  3,  1, -2,  1, -1, -2, -2,  0, -3, -1,  4, -3, -2, -1, -4},
{-2, -1,  3,  4, -3,  0,  1, -1,  0, -3, -4,  0, -3, -3, -2,  0, -1, -4, -3, -3,  4,  1, -1, -4},
{-1,  0,  0,  1, -3,  3,  4, -2,  0, -3, -3,  1, -1, -3, -1,  0, -1, -3, -2, -2,  1,  4, -1, -4},
{ 0, -1, -1, -1, -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -2,  0,  0, -2, -1, -1, -1, -1, -1, -4},
{-4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4,  1}
};

volatile int colrand[] = {3, 6, 4, 9, 10, 2, 7, 9, 2, 4, 5, 7, 9, 8, 10, 4, 9, 3, 7, 1, 10, 6, 3, 1, 6, 5, 10, 8, 4, 1, 5, 3, 3, 5, 2, 9, 6, 7, 1, 4, 7, 5, 4, 1, 7, 9, 1, 9, 5, 7, 8, 2, 6, 1, 3, 5, 2, 7, 4, 5, 5, 6, 2, 2, 4, 4, 1, 8, 4, 7, 9, 9, 9, 5, 7, 6, 10, 8, 1, 10, 7, 8, 6, 3, 3, 10, 9, 5, 1, 9, 4, 1, 6, 8, 4, 10, 7, 1, 8, 2, 3, 3, 10, 4, 4, 9, 1, 4, 10, 8, 3, 2, 4, 1, 1, 8, 5, 7, 2, 3, 4, 10, 1, 2, 9, 7, 4, 8};
volatile int rowrand[] = {7, 10, 5, 9, 7, 6, 2, 2, 3, 6, 7, 8, 3, 5, 4, 3, 8, 6, 9, 9, 4, 3, 2, 3, 4, 10, 6, 7, 10, 8, 3, 3, 9, 2, 1, 4, 7, 7, 2, 2, 8, 2, 5, 5, 1, 3, 1, 5, 8, 2, 4, 7, 5, 10, 4, 10, 5, 9, 5, 3, 7, 1, 1, 10, 2, 7, 3, 8, 5, 1, 6, 6, 1, 7, 4, 5, 7, 9, 4, 9, 4, 3, 1, 6, 6, 6, 5, 9, 6, 1, 3, 7, 3, 9, 1, 4, 8, 7, 7, 7, 3, 1, 2, 7, 7, 3, 5, 8, 8, 3, 9, 8, 3, 6, 10, 6, 10, 8, 10, 4, 5, 6, 1, 4, 2, 8, 8, 3};

////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
void nw_optimized(int *input_itemsets, int *output_itemsets, int *referrence,
        int max_rows, int max_cols, int penalty)
{
    int transfer_size = max_rows * max_cols;
    for( int blk = 1; blk <= (max_cols-1)/BLOCK_SIZE; blk++ )
    {
        for( int b_index_x = 0; b_index_x < blk; ++b_index_x)
        {
            int b_index_y = blk - 1 - b_index_x;
            int input_itemsets_l[(BLOCK_SIZE + 1) *(BLOCK_SIZE+1)] __attribute__ ((aligned (64)));
            int reference_l[BLOCK_SIZE * BLOCK_SIZE] __attribute__ ((aligned (64)));

            // Copy referrence to local memory
            for ( int i = 0; i < BLOCK_SIZE; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE; ++j)
                {
                    reference_l[i*BLOCK_SIZE + j] = referrence[max_cols*(b_index_y*BLOCK_SIZE + i + 1) + b_index_x*BLOCK_SIZE +  j + 1];
                }
            }

            // Copy input_itemsets to local memory
            for ( int i = 0; i < BLOCK_SIZE + 1; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE + 1; ++j)
                {
                    input_itemsets_l[i*(BLOCK_SIZE + 1) + j] = input_itemsets[max_cols*(b_index_y*BLOCK_SIZE + i) + b_index_x*BLOCK_SIZE +  j];
                }
            }

            // Compute
            for ( int i = 1; i < BLOCK_SIZE + 1; ++i )
            {
                for ( int j = 1; j < BLOCK_SIZE + 1; ++j)
                {
                    input_itemsets_l[i*(BLOCK_SIZE + 1) + j] = maximum( input_itemsets_l[(i - 1)*(BLOCK_SIZE + 1) + j - 1] + reference_l[(i - 1)*BLOCK_SIZE + j - 1],
                            input_itemsets_l[i*(BLOCK_SIZE + 1) + j - 1] - penalty,
                            input_itemsets_l[(i - 1)*(BLOCK_SIZE + 1) + j] - penalty);
                }
            }

            // Copy results to global memory
            for ( int i = 0; i < BLOCK_SIZE; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE; ++j)
                {
                    input_itemsets[max_cols*(b_index_y*BLOCK_SIZE + i + 1) + b_index_x*BLOCK_SIZE +  j + 1] = input_itemsets_l[(i + 1)*(BLOCK_SIZE+1) + j + 1];
                }
            }
        }
    }

    for ( int blk = 2; blk <= (max_cols-1)/BLOCK_SIZE; blk++ )
    {
        for( int b_index_x = blk - 1; b_index_x < (max_cols-1)/BLOCK_SIZE; ++b_index_x)
        {
            int b_index_y = (max_cols-1)/BLOCK_SIZE + blk - 2 - b_index_x;

            int input_itemsets_l[(BLOCK_SIZE + 1) *(BLOCK_SIZE+1)] __attribute__ ((aligned (64)));
            int reference_l[BLOCK_SIZE * BLOCK_SIZE] __attribute__ ((aligned (64)));

            // Copy referrence to local memory
            for ( int i = 0; i < BLOCK_SIZE; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE; ++j)
                {
                    reference_l[i*BLOCK_SIZE + j] = referrence[max_cols*(b_index_y*BLOCK_SIZE + i + 1) + b_index_x*BLOCK_SIZE +  j + 1];
                }
            }

            // Copy input_itemsets to local memory
            for ( int i = 0; i < BLOCK_SIZE + 1; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE + 1; ++j)
                {
                    input_itemsets_l[i*(BLOCK_SIZE + 1) + j] = input_itemsets[max_cols*(b_index_y*BLOCK_SIZE + i) + b_index_x*BLOCK_SIZE +  j];
                }
            }

            // Compute
            for ( int i = 1; i < BLOCK_SIZE + 1; ++i )
            {
                for ( int j = 1; j < BLOCK_SIZE + 1; ++j)
                {
                    input_itemsets_l[i*(BLOCK_SIZE + 1) + j] = maximum( input_itemsets_l[(i - 1)*(BLOCK_SIZE + 1) + j - 1] + reference_l[(i - 1)*BLOCK_SIZE + j - 1],
                            input_itemsets_l[i*(BLOCK_SIZE + 1) + j - 1] - penalty,
                            input_itemsets_l[(i - 1)*(BLOCK_SIZE + 1) + j] - penalty);
                }
            }

            // Copy results to global memory
            for ( int i = 0; i < BLOCK_SIZE; ++i )
            {
                for ( int j = 0; j < BLOCK_SIZE; ++j)
                {
                    input_itemsets[max_cols*(b_index_y*BLOCK_SIZE + i + 1) + b_index_x*BLOCK_SIZE +  j + 1] = input_itemsets_l[(i + 1)*(BLOCK_SIZE+1) + j +1];
                }
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
//! Run a simple test for CUDA
////////////////////////////////////////////////////////////////////////////////
void
main()
{
    int max_rows, max_cols, penalty;
    //int *matrix_cuda, *matrix_cuda_out, *referrence_cuda;
    //int size;


    // the lengths of the two sequences should be able to divided by 16.
    // And at current stage  max_rows needs to equal max_cols
    max_rows = 128;
    max_cols = 128;
    penalty  = 1;

    max_rows = max_rows + 1;
    max_cols = max_cols + 1;
    int referrence      [max_rows * max_cols];
    int input_itemsets  [max_rows * max_cols];
    int output_itemsets [max_rows * max_cols];

    for (int i = 0 ; i < max_cols; i++){
        for (int j = 0 ; j < max_rows; j++){
            input_itemsets[i*max_cols+j] = 0;
        }
    }

    for( int i=1; i< max_rows ; i++){    //please define your own sequence. 
        input_itemsets[i*max_cols] = rowrand[i-1];
    }
    for( int j=1; j< max_cols ; j++){    //please define your own sequence.
        input_itemsets[j] = colrand[j-1];
    }


    for (int i = 1 ; i < max_cols; i++){
        for (int j = 1 ; j < max_rows; j++){
            referrence[i*max_cols+j] = blosum62[input_itemsets[i*max_cols]][input_itemsets[j]];
        }
    }

    for( int i = 1; i< max_rows ; i++)
        input_itemsets[i*max_cols] = -i * penalty;
    for( int j = 1; j< max_cols ; j++)
        input_itemsets[j] = -j * penalty;

    nw_optimized( input_itemsets, output_itemsets, referrence,
        max_rows, max_cols, penalty );
}
