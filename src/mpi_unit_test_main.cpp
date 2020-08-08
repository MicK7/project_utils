#define DOCTEST_CONFIG_IMPLEMENT
#include "std_e/unit_test/mpi/doctest.hpp"

int main(int argc, char** argv) {
  MPI_Init(&argc, &argv);

  doctest::Context ctx;
  ctx.setOption("reporters", "mpi_reporter");
  ctx.setOption("force-colors", true);
  ctx.applyCommandLine(argc, argv);

  int test_result = ctx.run();

  MPI_Finalize();

  return test_result;
}
