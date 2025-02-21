#include <cub/cub.cuh>

template <typename T> T *init(std::initializer_list<T> list) {
  T *p = nullptr;
  cudaMalloc<T>(&p, sizeof(T) * list.size());
  cudaMemcpy(p, list.begin(), sizeof(T) * list.size(), cudaMemcpyHostToDevice);
  return p;
}

__global__ void iadd3_kernel(int x, int y, int z, int *output) {
  *output = cub::IADD3(x, y, z);
}

bool iadd3(int x, int y, int z) {
  int output, *d_output = init({0});
  iadd3_kernel<<<1, 1>>>(x, y, z, d_output);
  cudaMemcpy(&output, d_output, sizeof(int), cudaMemcpyDeviceToHost);
  if (output != x + y + z) {
    std::cout << "cub::IADD3 test failed"
                 "\n";
    std::cout << "input: " << x << " " << y << " " << z << "\n";
    std::cout << "expected: " << output << "\n";
    std::cout << "result: " << x + y + z << "\n";
    return false;
  }
  return true;
}

bool test_iadd3() {
  return iadd3(1, 2, 3) && iadd3(4, 5, 6) && iadd3(9991, 12, 7) &&
         iadd3(0, 1, 0);
}

__global__ void laneid_and_warpid(int *laneids, int *warpids) {
  unsigned tid =
      ((blockIdx.x + (blockIdx.y * gridDim.x)) * (blockDim.x * blockDim.y)) +
      (threadIdx.x + (threadIdx.y * blockDim.x));
  laneids[tid] = cub::LaneId();
  warpids[tid] = cub::WarpId();
}

bool test_laneid_warpid() {
  int *d_warpids, *d_laneids;
  cudaMalloc(&d_laneids, sizeof(int) * 66);
  cudaMalloc(&d_warpids, sizeof(int) * 66);
  laneid_and_warpid<<<2, 33>>>(d_laneids, d_warpids);
  cudaDeviceSynchronize();
  int laneids[66] = {0}, warpids[66] = {0};
  cudaMemcpy(laneids, d_laneids, sizeof(int) * 66, cudaMemcpyDeviceToHost);
  cudaMemcpy(warpids, d_warpids, sizeof(int) * 66, cudaMemcpyDeviceToHost);
  cudaDeviceSynchronize();
  std::map<int, int> cnt_laneid, cnt_warpid, cnt_laneid_num;
  for (int I = 0; I < 66; ++I) {
    cnt_warpid[warpids[I]]++;
    cnt_laneid[laneids[I]]++;
  }

  int total_warpid = 0;
  for (const auto &[k, v] : cnt_warpid)
    total_warpid += v;
  for (const auto &[k, v] : cnt_laneid)
    cnt_laneid_num[v]++;

  auto check_laneid_num = [&]() {
    if (cnt_laneid_num.size() != 2)
      return false;
    const auto first = *cnt_laneid_num.begin();
    const auto second = *std::next(cnt_laneid_num.begin());
    return first.first + 2 == second.first;
  };

  cudaFree(d_laneids);
  cudaFree(d_warpids);
  return total_warpid == 66 && check_laneid_num();
}

bool test_current_device() {
  unsigned CurDev = cub::CurrentDevice();
  return true;
}

bool test_device_count() {
  unsigned device_count = cub::DeviceCount();
  device_count = cub::DeviceCountCachedValue();
  device_count = cub::DeviceCountUncached();
  (void) device_count;
  return true;
}

bool test_sync_stream() {
  cub::SyncStream(0);
  cub::SyncStream((cudaStream_t)(uintptr_t)1);
  cub::SyncStream((cudaStream_t)(uintptr_t)2);
  cudaStream_t NewS;
  cudaStreamCreate(&NewS);
  cub::SyncStream(NewS);
  cudaStreamDestroy(NewS);
  (void) NewS;
  return true;
}

#define TEST(FUNC)                                                             \
  if (!FUNC()) {                                                               \
    printf(#FUNC " failed\n");                                                 \
    return 1;                                                                  \
  }

int main() {
  TEST(test_iadd3);
  TEST(test_laneid_warpid);
  TEST(test_current_device);
  TEST(test_device_count);
  TEST(test_sync_stream);
  return 0;
}
