// ----------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------

/**
 * @file
 * test_sssp.cu
 *
 * @brief Simple test driver program for Gunrock template.
 */

#include <gunrock/app/louvain/louvain_app.cu>
#include <gunrock/app/test_base.cuh>

using namespace gunrock;

/******************************************************************************
* Main
******************************************************************************/

/**
 * @brief Enclosure to the main function
 */
struct main_struct
{
    /**
     * @brief the actual main function, after type switching
     * @tparam VertexT    Type of vertex identifier
     * @tparam SizeT      Type of graph size, i.e. type of edge identifier
     * @tparam ValueT     Type of edge values
     * @param  parameters Command line parameters
     * @param  v,s,val    Place holders for type deduction
     * \return cudaError_t error message(s), if any
     */
    template <
        typename VertexT, // Use int as the vertex identifier
        typename SizeT,   // Use int as the graph size type
        typename ValueT>  // Use float as the value type
    cudaError_t operator()(util::Parameters &parameters,
        VertexT v, SizeT s, ValueT val)
    {
        typedef typename app::TestGraph<VertexT, SizeT, ValueT,
            graph::HAS_EDGE_VALUES | graph::HAS_CSR>
            GraphT;

        cudaError_t retval = cudaSuccess;
        util::CpuTimer cpu_timer;
        GraphT graph; // graph we process on

        cpu_timer.Start();
        GUARD_CU(graphio::LoadGraph(parameters, graph));
        cpu_timer.Stop();
        parameters.Set("load-time", cpu_timer.ElapsedMillis());

        VertexT  *ref_communities = NULL;
        bool quick = parameters.Get<bool>("quick");
        // compute reference CPU Louvain solution
        if (!quick)
        {
            bool quiet = parameters.Get<bool>("quiet");
            std::string validation = parameters.Get<std::string>("validation");
            util::PrintMsg("Computing reference value ...", !quiet);

            SizeT nodes = graph.nodes;
            ref_communities = new VertexT[nodes];
            //for (int i = 0; i < num_srcs; i++)
            {
                int i = 0;
                util::PrintMsg("__________________________", !quiet);
                float elapsed = app::louvain::CPU_Reference(
                    parameters, graph.csr(), ref_communities);
                util::PrintMsg("--------------------------\nRun "
                    + std::to_string(i) + " elapsed: "
                    + std::to_string(elapsed)
                    + " ms, q = " + std::to_string(app::louvain::Get_Modularity(
                        graph, ref_communities))
                    , !quiet);
            }
        }

        std::vector<std::string> switches{"advance-mode"};
        GUARD_CU(app::Switch_Parameters(parameters, graph, switches,
            [ref_communities](util::Parameters &parameters, GraphT &graph)
            {
                return app::louvain::RunTests(parameters, graph, ref_communities);
            }));

        if (!quick)
        {
            delete[] ref_communities; ref_communities = NULL;
        }
        return retval;
    }
};

int main(int argc, char** argv)
{
    cudaError_t retval = cudaSuccess;
    util::Parameters parameters("test Louvain (community detection)");
    GUARD_CU(graphio::UseParameters(parameters));
    GUARD_CU(app::louvain::UseParameters(parameters));
    GUARD_CU(app::UseParameters_test(parameters));
    GUARD_CU(parameters.Parse_CommandLine(argc, argv));
    if (parameters.Get<bool>("help"))
    {
        parameters.Print_Help();
        return cudaSuccess;
    }
    GUARD_CU(parameters.Check_Required());

    return app::Switch_Types<
        app::VERTEXT_U32B | //app::VERTEXT_U64B |
        app::SIZET_U32B | //app::SIZET_U64B |
        app::VALUET_F64B | app::DIRECTED | app::UNDIRECTED>
        (parameters, main_struct());
}

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
