/*
 * All changes to code are copyright, 2017, Zhu Li, zhuli@unm.edu
 */

#include <thrust/device_vector.h>
#include <thrust/copy.h>
#include <iostream>

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <sys/time.h>
#include <cuda.h>
#define THREAD_PER_BLOCK 512
#define SAMPLE_NUMBER 32768
#define SAMPLE_ATTRIBUTE_NUMBER 1024
#define INITIAL_WEIGHTS_RANGE 0.01
#define SAMPLE_VALUE_RANGE 50
#define CONVERGE_RATE 0.0001
#define ITERATION_NUMBER 50
#define MICROSEC_IN_SEC 1000000

//#define DEBUG
//#define WEIGHT_ZERO
/**
 *
 * @param n Length of the array.
 * @param range Range of the numbers in the array is [0, range].
 * @return An array filled with random numbers.
 */
float* generateRandomVectorFloat(int n, float range) {
  float* ptr = (float*)malloc(sizeof(float) * n);
  if (ptr != NULL) {
    for (int i = 0; i < n; i++) {
      ptr[i] =  (range * rand() / RAND_MAX) - range / 2;
    }
  }
  return ptr;
}

void output_device_vector(float* x, int length) {
  thrust::device_ptr<float> x_thr(x);
  thrust::device_vector<float> x_vector(x_thr, x_thr + length);
  thrust::copy(x_vector.begin(), x_vector.end(), std::ostream_iterator<float>(std::cout, "\t"));
  printf("\n");
}
/**
 *  return dot product of vector x and w.
 */
__host__ __device__ float dotProduct(float* x, float* w, int n) {
  float sum = 0;
  for (int i = 0; i < n; i++) {
    sum += x[i] * w[i];
  }
  return sum;
}


__host__ __device__ float logisticFunction(float* x, float* w, int n, float w0){
  float sum = w0 + dotProduct(x, w, n);
  return 1 / (1 + exp(sum));
}

template <unsigned int block_size> __global__ void calculate_difference(float* delta, float* difference, float* x, float* weights, float w0, float* y, float* weights_grid) {
  __shared__ float shared_weights[SAMPLE_ATTRIBUTE_NUMBER];
  int tid = threadIdx.x;
  int i = blockDim.x * blockIdx.x + tid;
  if (tid < SAMPLE_ATTRIBUTE_NUMBER) {
    for (int j = 0; tid + j < SAMPLE_ATTRIBUTE_NUMBER; j += blockDim.x) {
      shared_weights[tid + j] = weights[tid + j];
    }
  }
  delta += i * SAMPLE_ATTRIBUTE_NUMBER;
  x += i * SAMPLE_ATTRIBUTE_NUMBER;
  __syncthreads();
  difference[i] = logisticFunction(x, shared_weights, SAMPLE_ATTRIBUTE_NUMBER, w0) + y[i] - 1;
  for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
    *(delta + j) = *(x + j) * difference[i] * CONVERGE_RATE;
  }
  __syncthreads();
  int stride = 0;
    if (tid < 256) {
      stride = 256 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }
      __syncthreads();
    }

    if (tid < 128) {
      stride = 128 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }
      __syncthreads();
    }

    if (tid < 64) {
      stride = 64 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }
      __syncthreads();
    }


  if (tid < 32) {
      stride = 32 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }

      stride = 16 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }

      stride = 8 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }

      stride = 4 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }

      stride = 2 * SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
      }

      stride = SAMPLE_ATTRIBUTE_NUMBER;
      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
        delta[j] += delta[stride + j];
    }
  }
//  if (block_size >= 512) {
//    if (tid < 256) {
//      stride = 256 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//      __syncthreads();
//    }
//  }
//  if (block_size >= 256) {
//    if (tid < 128) {
//      stride = 128 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//      __syncthreads();
//    }
//  }
//  if (block_size >= 128) {
//    if (tid < 64) {
//      stride = 64 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//      __syncthreads();
//    }
//  }
//
//  if (tid < 32) {
//    if (block_size >= 64) {
//      stride = 32 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//    if (block_size >= 32) {
//      stride = 16 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//    if (block_size >= 16) {
//      stride = 8 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//    if (block_size >= 8) {
//      stride = 4 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//    if (block_size >= 4) {
//      stride = 2 * SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//    if (block_size >= 2) {
//      stride = SAMPLE_ATTRIBUTE_NUMBER;
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        delta[j] += delta[stride + j];
//      }
//    }
//  }


//  int sum_holder_limit = blockDim.x / 2;
//  int sum_stride = blockDim.x / 2;
//  while (sum_stride > 0) {
//    if (tid < sum_holder_limit) {
//      for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
//        *(delta + j) += *(delta + sum_stride * SAMPLE_ATTRIBUTE_NUMBER + j);
//      }
//    }
//    sum_holder_limit /= 2;
//    sum_stride /= 2;
//    __syncthreads();
//  }
  if (tid == 0) {
    weights_grid += blockIdx.x * SAMPLE_ATTRIBUTE_NUMBER;
    delta -= tid * SAMPLE_ATTRIBUTE_NUMBER;
    for (int j = 0; j < SAMPLE_ATTRIBUTE_NUMBER; j++) {
      weights_grid[j] += delta[j];
    }
  }
}

__global__ void block_reduce(float *delta, float *weights, int block_number) {
  int j = blockDim.x * blockIdx.x + threadIdx.x;
  for (int i = 0; i < block_number; i++) {
    weights[j] += *(delta + i * SAMPLE_ATTRIBUTE_NUMBER + j);
  }
}

int main() {

  srand(time(NULL));
  // initialize the weights randomly
  float w0 = (INITIAL_WEIGHTS_RANGE * rand() / RAND_MAX) - INITIAL_WEIGHTS_RANGE / 2;
  float* weights = generateRandomVectorFloat(SAMPLE_ATTRIBUTE_NUMBER, INITIAL_WEIGHTS_RANGE);
#ifdef WEIGHT_ZERO
  for (int i = 0; i < SAMPLE_ATTRIBUTE_NUMBER; i++) {
    weights[i] = 0;
  }
#endif
  float* x = (float*)malloc(SAMPLE_NUMBER * SAMPLE_ATTRIBUTE_NUMBER * sizeof(float));
  x = generateRandomVectorFloat(SAMPLE_NUMBER * SAMPLE_ATTRIBUTE_NUMBER, SAMPLE_VALUE_RANGE);

  // Set all benchmark weights as 0.5 or -0.5 randomly and generate the corresponding labels.
  // So we could test the effectiveness of the program according to whether
  // the program could predict the labels generated with benchmark weights
  float* y = (float*)malloc(SAMPLE_NUMBER * sizeof(float));
  float* benchMarkWeights = (float*)malloc(SAMPLE_ATTRIBUTE_NUMBER * sizeof(float));
  float benchMarkWeight0 = rand() % 2 - 0.5;
  for (int i = 0; i < SAMPLE_ATTRIBUTE_NUMBER; i++) {
    benchMarkWeights[i] = rand() % 2 - 0.5;
  }
  for (int i = 0; i < SAMPLE_NUMBER; i++) {
    y[i] = logisticFunction(x + i * SAMPLE_ATTRIBUTE_NUMBER, benchMarkWeights, SAMPLE_ATTRIBUTE_NUMBER, benchMarkWeight0) > 0.5 ? 0 : 1;
  }
  struct timeval tv;
  gettimeofday(&tv, NULL);
  long start = tv.tv_usec + tv.tv_sec * MICROSEC_IN_SEC;
  int block_number = SAMPLE_NUMBER / THREAD_PER_BLOCK;
  if (block_number == 0) {
    block_number = 1;
  }
  int thread_number = SAMPLE_NUMBER;
  if (thread_number > THREAD_PER_BLOCK) {
    thread_number = THREAD_PER_BLOCK;
  }

  int block_number_weights = SAMPLE_ATTRIBUTE_NUMBER / THREAD_PER_BLOCK;
  if (block_number_weights == 0) {
    block_number_weights = 1;
  }
  int thread_number_weights = SAMPLE_ATTRIBUTE_NUMBER;
  if (thread_number_weights > THREAD_PER_BLOCK) {
    thread_number_weights = THREAD_PER_BLOCK;
  }

  float *difference, *weight_device, *x_device, *y_device, *delta_device, *weight_grid;
  printf("Start memory alloc\t");
  gettimeofday(&tv, NULL);
  long diff = (tv.tv_sec * MICROSEC_IN_SEC + tv.tv_usec - start) / 1000;
  printf("Time taken: %ld seconds %ld milliseconds\n", diff / 1000, diff % 1000);
  cudaMalloc((void**)&difference, SAMPLE_NUMBER * sizeof(float));
  cudaMalloc((void**)&weight_device, SAMPLE_ATTRIBUTE_NUMBER * sizeof(float));
  cudaMalloc((void**)&delta_device, SAMPLE_ATTRIBUTE_NUMBER * SAMPLE_NUMBER * sizeof(float));
  cudaMalloc((void**)&x_device, SAMPLE_ATTRIBUTE_NUMBER * SAMPLE_NUMBER * sizeof(float));
  cudaMalloc((void**)&y_device, SAMPLE_NUMBER * sizeof(float));
  cudaMalloc((void**)&weight_grid, SAMPLE_ATTRIBUTE_NUMBER * block_number * sizeof(float));
  printf("Start memory copy\t");
  gettimeofday(&tv, NULL);
  diff = (tv.tv_sec * MICROSEC_IN_SEC + tv.tv_usec - start) / 1000;
  printf("Time taken: %ld seconds %ld milliseconds\n", diff / 1000, diff % 1000);
  cudaMemcpy(x_device, x, SAMPLE_ATTRIBUTE_NUMBER * SAMPLE_NUMBER * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(y_device, y, SAMPLE_NUMBER * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(weight_device, weights, SAMPLE_ATTRIBUTE_NUMBER * sizeof(float), cudaMemcpyHostToDevice);
#ifdef DEBUG
  printf("Block number:%d\n", block_number);
  printf("Thread number:%d\n", thread_number);
  printf("Original weights:\n");
  output_device_vector(weight_device, SAMPLE_ATTRIBUTE_NUMBER);
#endif
  printf("Start calculation\t");
  gettimeofday(&tv, NULL);
  long diff_start = (tv.tv_sec * MICROSEC_IN_SEC + tv.tv_usec - start) / 1000;
  printf("Time taken: %ld seconds %ld milliseconds\n", diff_start / 1000, diff_start % 1000);
  for (int k = 0; k < ITERATION_NUMBER; k++) {
    calculate_difference<THREAD_PER_BLOCK><<<block_number,thread_number>>>(delta_device, difference, x_device, weight_device, w0, y_device, weight_grid);
#ifdef DEBUG
    printf("x:\n");
    output_device_vector(x, SAMPLE_ATTRIBUTE_NUMBER * SAMPLE_NUMBER);
    printf("Delta:\n");
    output_device_vector(delta_device, SAMPLE_ATTRIBUTE_NUMBER * SAMPLE_NUMBER);
    printf("Difference:\n");
    output_device_vector(difference, SAMPLE_NUMBER);
    for (int i = 0; i < 10; i++) {
      printf("delta %d:\n", i);
      output_device_vector(delta_device + i * SAMPLE_ATTRIBUTE_NUMBER, SAMPLE_ATTRIBUTE_NUMBER);
    }
#endif
    block_reduce<<<block_number_weights,thread_number_weights>>>(weight_grid, weight_device, block_number);
#ifdef DEBUG
    printf("weight_device after update:\n");
    output_device_vector(weight_device, SAMPLE_ATTRIBUTE_NUMBER);
#endif
  }
  printf("End calculation\t");
  gettimeofday(&tv, NULL);
  long diff_end = (tv.tv_sec * MICROSEC_IN_SEC + tv.tv_usec - start) / 1000;
  printf("Time taken: %ld seconds %ld milliseconds\n", diff_end / 1000, diff_end % 1000);
  float calculation_time = (diff_end - diff_start) * 1.0 / ITERATION_NUMBER;
  printf("Time taken by each kernel: %lf milliseconds \n", calculation_time);
  cudaMemcpy(weights, weight_device, SAMPLE_ATTRIBUTE_NUMBER * sizeof(float), cudaMemcpyDeviceToHost);
  cudaFree(x_device);
  cudaFree(y_device);
  cudaFree(weight_device);
  cudaFree(difference);
  cudaFree(weight_grid);
#ifdef DEBUG
  for (int i = 0; i < SAMPLE_ATTRIBUTE_NUMBER; i++) {
    printf("Benchmark weight: %lf Estimated weight:%lf\n", benchMarkWeights[i], weights[i]);
  }
#endif
  // Predict the labels with weights estimated with logistic regression.
  float error = 0;
  for (int i = 0; i < SAMPLE_NUMBER; i++) {
    float predict = logisticFunction(x + i * SAMPLE_ATTRIBUTE_NUMBER, weights, SAMPLE_ATTRIBUTE_NUMBER, w0) > 0.5 ? 0 : 1;
#ifdef DEBUG
    printf("y[%d]: %lf Predicted: %lf\n", i, y[i], predict);
#endif
    error += fabs(predict - y[i]);
  }
  printf("Average error:%f\n", error / SAMPLE_NUMBER);
  printf("Finish verification\t");
  gettimeofday(&tv, NULL);
  diff = (tv.tv_sec * MICROSEC_IN_SEC + tv.tv_usec - start) / 1000;
  printf("Time taken: %ld seconds %ld milliseconds\n", diff / 1000, diff % 1000);
  free(x);
  free(y);
  free(weights);
  free(benchMarkWeights);
  return 0;
}



