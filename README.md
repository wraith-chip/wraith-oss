# WRAITH:  Resource-Efficient Dataflow Accelerator

This repository is an open source release of our accelerator chip, WRAITH. Our chip was taped out on the TSMC 65nm process, using 1mm^2 area, through Muse Semiconductor as our Multiparty Wafer organization.

Our final report can be viewed at `docs/report.pdf`, which detail features, architecture, and our process.

This repository is released under the MIT License.

Contributors:

- Prakhar Gupta [(Website)](https://screamingpigeon.github.io/) [(LinkedIn)](https://www.linkedin.com/in/prakg/)
- Ingi Helgason [(Website)](https://atmospheal.com/) [(LinkedIn)](https://www.linkedin.com/in/ingibhelgason/)
- Pradyun Narkadamilli [(Website)](https://pradyun.net/) [(LinkedIn)](https://www.linkedin.com/in/pradyun/)
- Sam Ruggerio [(Website)](https://ruggerio.phd) [(LinkedIn)](https://www.linkedin.com/in/surgdev)

## Open Source Differences

- `io.sv` used specific drive strength z-buffer cells for synthesis. Since we are unable to share details of the TSMC PDK, this was replaced with a behaviorial model.
- SRAM wrappers under `rvtu/sram_wrappers` and `scratchpad/scratchpad_sram_wrapper.sv` provide a FF behaviorial model of the SRAMs we used in production.
- Makefiles for simulation, synthesis, and PnR were not included, due to the intertwining with TSMC's PDK.
