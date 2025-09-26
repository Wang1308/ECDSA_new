/* Copyright (c) 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */
/* SPDX-License-Identifier: GPL-2.0-or-later */
/* See the file LICENSE for further information */

#include "main.h"
#include "encoding.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include "libfdt/libfdt.h"
#include "uart/uart.h"
#include <kprintf/kprintf.h>
#include <stdio.h>

#include <platform.h>
// #include <stdatomic.h>
#include <plic/plic_driver.h>
#include <inttypes.h>

volatile unsigned long dtb_target;

// Structures for registering different interrupt handlers
// for different parts of the application.
void no_interrupt_handler (void) {};
function_ptr_t g_ext_interrupt_handlers[32];
function_ptr_t g_time_interrupt_handler = no_interrupt_handler;
plic_instance_t g_plic;// Instance data for the PLIC.

#define RTC_FREQ 1000000 // TODO: This is now extracted

void boot_fail(long code, int trap)
{
  kputs("BOOT FAILED\r\nCODE: ");
  uart_put_hex((void*)uart_reg, code);
  kputs("\r\nTRAP: ");
  uart_put_hex((void*)uart_reg, trap);
  while(1);
}

void handle_m_ext_interrupt(){
  int int_num  = PLIC_claim_interrupt(&g_plic);
  if ((int_num >=1 ) && (int_num < 32/*plic_ndevs*/)) {
    g_ext_interrupt_handlers[int_num]();
  }
  else {
    boot_fail((long) read_csr(mcause), 1);
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
  }
  PLIC_complete_interrupt(&g_plic, int_num);
}

void handle_m_time_interrupt() {
  clear_csr(mie, MIP_MTIP);

  // Reset the timer for 1s in the future.
  // This also clears the existing timer interrupt.

  volatile unsigned long *mtime    = (unsigned long*)(CLINT_CTRL_ADDR + CLINT_MTIME);
  volatile unsigned long *mtimecmp = (unsigned long*)(CLINT_CTRL_ADDR + CLINT_MTIMECMP);
  unsigned long now = *mtime;
  unsigned long then = now + RTC_FREQ;
  *mtimecmp = then;

  g_time_interrupt_handler();

  // Re-enable the timer interrupt.
  set_csr(mie, MIP_MTIP);
}

uintptr_t handle_trap(uintptr_t mcause, uintptr_t epc)
{
  // External Machine-Level interrupt from PLIC
  if ((mcause & MCAUSE_INT) && ((mcause & MCAUSE_CAUSE) == IRQ_M_EXT)) {
    handle_m_ext_interrupt();
    // External Machine-Level interrupt from PLIC
  } else if ((mcause & MCAUSE_INT) && ((mcause & MCAUSE_CAUSE) == IRQ_M_TIMER)){
    handle_m_time_interrupt();
  }
  else {
    boot_fail((long) read_csr(mcause), 1);
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
  }
  return epc;
}

// Helpers for fdt

void remove_from_dtb(void* dtb_target, const char* path) {
  int nodeoffset;
  int err;
	do{
    nodeoffset = fdt_path_offset((void*)dtb_target, path);
    if(nodeoffset >= 0) {
      kputs("\r\nINFO: Removing ");
      kputs(path);
      err = fdt_del_node((void*)dtb_target, nodeoffset);
      if (err < 0) {
        kputs("\r\nWARNING: Cannot remove a subnode ");
        kputs(path);
      }
    }
  } while (nodeoffset >= 0) ;
}

static int fdt_translate_address(void *fdt, uint64_t reg, int parent,
				 unsigned long *addr)
{
	int i, rlen;
	int cell_addr, cell_size;
	const fdt32_t *ranges;
	uint64_t offset = 0, caddr = 0, paddr = 0, rsize = 0;

	cell_addr = fdt_address_cells(fdt, parent);
	if (cell_addr < 1)
		return -FDT_ERR_NOTFOUND;

	cell_size = fdt_size_cells(fdt, parent);
	if (cell_size < 0)
		return -FDT_ERR_NOTFOUND;

	ranges = fdt_getprop(fdt, parent, "ranges", &rlen);
	if (ranges && rlen > 0) {
		for (i = 0; i < cell_addr; i++)
			caddr = (caddr << 32) | fdt32_to_cpu(*ranges++);
		for (i = 0; i < cell_addr; i++)
			paddr = (paddr << 32) | fdt32_to_cpu(*ranges++);
		for (i = 0; i < cell_size; i++)
			rsize = (rsize << 32) | fdt32_to_cpu(*ranges++);
		if (reg < caddr || caddr >= (reg + rsize )) {
			//kprintf("invalid address translation\n");
			return -FDT_ERR_NOTFOUND;
		}
		offset = reg - caddr;
		*addr = paddr + offset;
	} else {
		/* No translation required */
		*addr = reg;
	}

	return 0;
}

int fdt_get_node_addr_size(void *fdt, int node, unsigned long *addr,
			   unsigned long *size)
{
	int parent, len, i, rc;
	int cell_addr, cell_size;
	const fdt32_t *prop_addr, *prop_size;
	uint64_t temp = 0;

	parent = fdt_parent_offset(fdt, node);
	if (parent < 0)
		return parent;
	cell_addr = fdt_address_cells(fdt, parent);
	if (cell_addr < 1)
		return -FDT_ERR_NOTFOUND;

	cell_size = fdt_size_cells(fdt, parent);
	if (cell_size < 0)
		return -FDT_ERR_NOTFOUND;

	prop_addr = fdt_getprop(fdt, node, "reg", &len);
	if (!prop_addr)
		return -FDT_ERR_NOTFOUND;
	prop_size = prop_addr + cell_addr;

	if (addr) {
		for (i = 0; i < cell_addr; i++)
			temp = (temp << 32) | fdt32_to_cpu(*prop_addr++);
		do {
			if (parent < 0)
				break;
			rc  = fdt_translate_address(fdt, temp, parent, addr);
			if (rc)
				break;
			parent = fdt_parent_offset(fdt, parent);
			temp = *addr;
		} while (1);
	}
	temp = 0;

	if (size) {
		for (i = 0; i < cell_size; i++)
			temp = (temp << 32) | fdt32_to_cpu(*prop_size++);
		*size = temp;
	}

	return 0;
}

int fdt_parse_hart_id(void *fdt, int cpu_offset, uint32_t *hartid)
{
	int len;
	const void *prop;
	const fdt32_t *val;

	if (!fdt || cpu_offset < 0)
		return -FDT_ERR_NOTFOUND;

	prop = fdt_getprop(fdt, cpu_offset, "device_type", &len);
	if (!prop || !len)
		return -FDT_ERR_NOTFOUND;
	if (strncmp (prop, "cpu", strlen ("cpu")))
		return -FDT_ERR_NOTFOUND;

	val = fdt_getprop(fdt, cpu_offset, "reg", &len);
	if (!val || len < sizeof(fdt32_t))
		return -FDT_ERR_NOTFOUND;

	if (len > sizeof(fdt32_t))
		val++;

	if (hartid)
		*hartid = fdt32_to_cpu(*val);

	return 0;
}

int fdt_parse_max_hart_id(void *fdt, uint32_t *max_hartid)
{
	uint32_t hartid;
	int err, cpu_offset, cpus_offset;

	if (!fdt)
		return -FDT_ERR_NOTFOUND;
	if (!max_hartid)
		return 0;

	*max_hartid = 0;

	cpus_offset = fdt_path_offset(fdt, "/cpus");
	if (cpus_offset < 0)
		return cpus_offset;

	fdt_for_each_subnode(cpu_offset, fdt, cpus_offset) {
		err = fdt_parse_hart_id(fdt, cpu_offset, &hartid);
		if (err)
			continue;

		if (hartid > *max_hartid)
			*max_hartid = hartid;
	}

	return 0;
}

int fdt_find_or_add_subnode(void *fdt, int parentoffset, const char *name)
{
  int offset;

  offset = fdt_subnode_offset(fdt, parentoffset, name);

  if (offset == -FDT_ERR_NOTFOUND)
    offset = fdt_add_subnode(fdt, parentoffset, name);

  if (offset < 0) {
  	uart_puts((void*)uart_reg, fdt_strerror(offset));
  	uart_puts((void*)uart_reg, "\r\n");
  }

  return offset;
}
int timescale_freq = 0;

// Register to extract
unsigned long uart_reg = 0;
int tlclk_freq;
unsigned long plic_reg;
int plic_max_priority;
int plic_ndevs;
// int timescale_freq;

unsigned long ed_reg;


// #define POINTMUL_BASE     0x10004000UL
// #define REG32(x)          (*(volatile uint32_t *)(x))


#define S_BASE             0x6C   // 8 words thay the theo dia chi scala
#define PX_BASE           0x2C   // 8 words thay the theo dia chi scala
#define PY_BASE            0x4C   // 8 words thay the theo dia chi scala
#define QX_BASE           0x8C   // 8 words thay the theo dia chi scala
#define QY_BASE            0xAC   // 8 words thay the theo dia chi scala

#define ADDR_BASE 	  0x04 // thay the theo dia chi scala
#define DATA_IN_BASE 	  0x08 // thay the theo dia chi scala

#define WR_EN_BASE        0x00 // thay the theo dia chi scala (tin hieu wr_en)
#define GEN_RESET_BASE    0x28 // thay the theo dia chi scala
#define DONE_BASE         0xCC // thay the theo dia chi scala


#define ADDR_PARAM_p	  0x0
#define ADDR_PARAM_n	  0x1
#define ADDR_PARAM_a	  0x2
#define ADDR_PARAM_b	  0x3
#define ADDR_BASE_Px	  0x4
#define ADDR_BASE_Py	  0x5

#define CTRL_WR_EN        0x1
#define CTRL_GEN_RESET    0x1


#define STATUS_BUSY       0x1
#define STATUS_DONE       0x2


static inline void mmio_write32(unsigned long base, uint32_t offset, uint32_t value) {
*(volatile uint32_t *)((uintptr_t)base + offset) = value;
}
static inline uint32_t mmio_read32(unsigned long base, uint32_t offset) {
return *(volatile uint32_t *)((uintptr_t)base + offset);
}

// helper versions for vector operations using mmio funcs
static void write_vec(unsigned long base, uint32_t offset, const uint32_t *vec) {
for (int i = 0; i < 8; i++) {
mmio_write32(base, offset + i*4, vec[i]);
}
}


static void read_vec(unsigned long base, uint32_t offset, uint32_t *vec) {
for (int i = 0; i < 8; i++) {
vec[i] = mmio_read32(base, offset + i*4);
}
}

static inline void uart_put_char(void *uart_reg, char c) {
    volatile uint32_t *tx = (uint32_t *)uart_reg;
    *tx = (uint32_t)c;
}

//HART 0 runs main
int main(int id, unsigned long dtb)
{
  // Use the FDT to get some devices
  int nodeoffset;
  int err = 0;
  int len;
	const fdt32_t *val;
  
  // 1. Get the uart reg
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/serial");
  if (nodeoffset < 0) while(1);
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &uart_reg, NULL);
  if (err < 0) while(1);
  // NOTE: If want to force UART, uncomment these
  //uart_reg = 0x64000000;
  //tlclk_freq = 20000000;
  _REG32(uart_reg, UART_REG_TXCTRL) = UART_TXEN;
  _REG32(uart_reg, UART_REG_RXCTRL) = UART_RXEN;
  
  // 2. Get tl_clk 
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/subsystem_pbus_clock");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/soc/subsystem_pbus_clock'\r\nAborting...");
    while(1);
  }
  val = fdt_getprop((void*)dtb, nodeoffset, "clock-frequency", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no clock-frequency in '/soc/subsystem_pbus_clock'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  tlclk_freq = fdt32_to_cpu(*val);
  _REG32(uart_reg, UART_REG_DIV) = uart_min_clk_divisor(tlclk_freq, 115200);
  
  // 3. Get the mem_size
  nodeoffset = fdt_path_offset((void*)dtb, "/memory");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/memory'\r\nAborting...");
    while(1);
  }
  unsigned long mem_base, mem_size;
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &mem_base, &mem_size);
  if (err < 0) {
    kputs("\r\nCannot get reg space from '/memory'\r\nAborting...");
    while(1);
  }
  unsigned long ddr_size = (unsigned long)mem_size; // TODO; get this
  unsigned long ddr_end = (unsigned long)mem_base + ddr_size;
  
  // 4. Get the number of cores
  uint32_t num_cores = 0;
  err = fdt_parse_max_hart_id((void*)dtb, &num_cores);
  num_cores++; // Gives maxid. For max cores we need to add 1
  
  // 5. Get the plic parameters
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/interrupt-controller");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &plic_reg, NULL);
  if (err < 0) {
    kputs("\r\nCannot get reg space from '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  
  val = fdt_getprop((void*)dtb, nodeoffset, "riscv,ndev", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no riscv,ndev in '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  plic_ndevs = fdt32_to_cpu(*val);
  
  val = fdt_getprop((void*)dtb, nodeoffset, "riscv,max-priority", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no riscv,max-priority in '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  plic_max_priority = fdt32_to_cpu(*val);

  // Disable the machine & timer interrupts until setup is done.
  clear_csr(mstatus, MSTATUS_MIE);
  clear_csr(mie, MIP_MEIP);
  clear_csr(mie, MIP_MTIP);
  
  if(plic_reg != 0) {
    PLIC_init(&g_plic,
              plic_reg,
              plic_ndevs,
              plic_max_priority);
  }
  
  // Display some information
#define DEQ(mon, x) ((cdate[0] == mon[0] && cdate[1] == mon[1] && cdate[2] == mon[2]) ? x : 0)
  const char *cdate = __DATE__;
  int month =
    DEQ("Jan", 1) | DEQ("Feb",  2) | DEQ("Mar",  3) | DEQ("Apr",  4) |
    DEQ("May", 5) | DEQ("Jun",  6) | DEQ("Jul",  7) | DEQ("Aug",  8) |
    DEQ("Sep", 9) | DEQ("Oct", 10) | DEQ("Nov", 11) | DEQ("Dec", 12);

  char date[11] = "YYYY-MM-DD";
  date[0] = cdate[7];
  date[1] = cdate[8];
  date[2] = cdate[9];
  date[3] = cdate[10];
  date[5] = '0' + (month/10);
  date[6] = '0' + (month%10);
  date[8] = cdate[4];
  date[9] = cdate[5];

  // Post the serial number and build info
  extern const char * gitid;

  kputs("\r\nRATONA Demo:       ");
  kputs(date);
  kputs("-");
  kputs(__TIME__);
  kputs("-");
  kputs(gitid);
  kputs("\r\nGot TL_CLK: ");
  uart_put_dec((void*)uart_reg, tlclk_freq);
  kputs("\r\nGot NUM_CORES: ");
  uart_put_dec((void*)uart_reg, num_cores);

  // Copy the DTB
  dtb_target = ddr_end - 0x200000UL; // - 2MB
  err = fdt_open_into((void*)dtb, (void*)dtb_target, 0x100000UL); // - 1MB only for the DTB
  if (err < 0) {
    kputs(fdt_strerror(err));
    kputs("\r\n");
    boot_fail(-err, 4);
  }
  //memcpy((void*)dtb_target, (void*)dtb, fdt_size(dtb));
  
  // Put the choosen if non existent, and put the bootargs
  nodeoffset = fdt_find_or_add_subnode((void*)dtb_target, 0, "chosen");
  if (nodeoffset < 0) boot_fail(-nodeoffset, 2);
	
  const char* str = "console=hvc0 earlycon=sbi";
  err = fdt_setprop((void*)dtb_target, nodeoffset, "bootargs", str, strlen(str) + 1);
  if (err < 0) boot_fail(-err, 3);

  // Get the timebase-frequency for the cpu@0
  nodeoffset = fdt_path_offset((void*)dtb_target, "/cpus/cpu@0");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/cpus/cpu@0'\r\nAborting...");
    while(1);
  }
  val = fdt_getprop((void*)dtb_target, nodeoffset, "timebase-frequency", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no timebase-frequency in '/cpus/cpu@0'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  timescale_freq = fdt32_to_cpu(*val);
  kputs("\r\nGot TIMEBASE: ");
  uart_put_dec((void*)uart_reg, timescale_freq);
	
	// Put the timebase-frequency for the cpus
  nodeoffset = fdt_subnode_offset((void*)dtb_target, 0, "cpus");
	if (nodeoffset < 0) {
	  kputs("\r\nCannot find 'cpus'\r\nAborting...");
    while(1);
	}
	err = fdt_setprop_u32((void*)dtb_target, nodeoffset, "timebase-frequency", 1000000);
	if (err < 0) {
	  kputs("\r\nCannot set 'timebase-frequency' in 'timebase-frequency'\r\nAborting...");
    while(1);
	}

	// Pack the FDT and place the data after it
	fdt_pack((void*)dtb_target);


  // TODO: From this point, insert any code
  kputs("\r\n\n\nWelcome! Hello world!\r\n\n");
  
  // Doi ten device tree cua module o duoi nay
  nodeoffset = fdt_node_offset_by_compatible((void*)dtb_target,0, "uec,ecdsa_block-0");
 if (nodeoffset < 0) {
   kputs("\r\nCannot find 'uec,ecdsa_block-0'\r\nAborting...");
   while(1);
 }
 err = fdt_get_node_addr_size((void*)dtb_target, nodeoffset, &ed_reg, NULL);
 if (err < 0) {
   kputs("\r\nCannot get reg space from compatible 'uec,ecdsa_block-0'\r\nAborting...");
   while(1);
 }
 
 uint32_t p_words[8] = {
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
    0x00000000, 0x00000000, 0x00000001, 0xFFFFFFFF
  };
 
 uint32_t n_words[8] = {
    0xFC632551, 0xF3B9CAC2, 0xA7179E84, 0xBCE6FAAD,
    0xFFFFFFFF, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF
  };
  
  uint32_t a_words[8] = {
    0xFFFFFFFC, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
    0x00000000, 0x00000000, 0x00000001, 0xFFFFFFFF
  };
  
  uint32_t b_words[8] = {
    0x27D2604B, 0x3BCE3C3E, 0xCC53B0F6, 0x651D06B0,
    0x769886BC, 0xB3EBBD55, 0xAA3A93E7, 0x5AC635D8
  };
  
 uint32_t s[8]  = {
   0x00000005, 0x00000000, 0x00000000, 0x00000000,
   0x00000000, 0x00000000, 0x00000000, 0x00000000
};


   uint32_t in_pointx[8] = {
   0xd898c296, 0xf4a13945, 0x2deb33a0, 0x77037d81,
   0x63a440f2, 0xf8bce6e5, 0xe12c4247, 0x6b17d1f2
};


   uint32_t in_pointy[8] = {
   0x37bf51f5, 0xcbb64068, 0x6b315ece, 0x2bce3357,
   0x7c0f9e16, 0x8ee7eb4a, 0xfe1a7f9b, 0x4fe342e2
};


// --- START PointMul test ---
kprintf("Start PointMul test...\r\n");
kprintf("POINTMUL base address = 0x%" PRIxPTR "\r\n", (uintptr_t)ed_reg);

uint32_t qx[8], qy[8];

// 1. Reset IP va cau hinh tham so
// mmio_write32(ed_reg, CTRL_REG, CTRL_SOFT_RESET);
// kprintf("Reset = 1...\r\n");
mmio_write32(ed_reg, WR_EN_BASE, CTRL_WR_EN);
write_vec(ed_reg, DATA_IN_BASE, p_words);
mmio_write32(ed_reg, ADDR_BASE, ADDR_PARAM_p);
write_vec(ed_reg, DATA_IN_BASE, n_words);
mmio_write32(ed_reg, ADDR_BASE, ADDR_PARAM_n);
write_vec(ed_reg, DATA_IN_BASE, a_words);
mmio_write32(ed_reg, ADDR_BASE, ADDR_PARAM_a);
write_vec(ed_reg, DATA_IN_BASE, b_words);
mmio_write32(ed_reg, ADDR_BASE, ADDR_PARAM_b);
write_vec(ed_reg, DATA_IN_BASE, in_pointx);
mmio_write32(ed_reg, ADDR_BASE, ADDR_BASE_Px);
write_vec(ed_reg, DATA_IN_BASE, in_pointy);
mmio_write32(ed_reg, ADDR_BASE, ADDR_BASE_Py);
mmio_write32(ed_reg, WR_EN_BASE, 0x0);

// 2. Clear DONE cũ
// mmio_write32(ed_reg, CLEAR_W1C_REG, STATUS_DONE);

// 3. Ghi S, Px, Py SAU khi reset
write_vec(ed_reg, S_BASE, s);
write_vec(ed_reg, PX_BASE, px);
write_vec(ed_reg, PY_BASE, py);
kprintf("Write s, Px, Py done.\r\n");

mmio_write32(ed_reg, GEN_RESET_BASE, CTRL_GEN_RESET);
mmio_write32(ed_reg, GEN_RESET_BASE, 0x0); 

volatile unsigned long *mtime = (unsigned long*)(CLINT_CTRL_ADDR + CLINT_MTIME);
unsigned long t_start = *mtime;  // Lấy thời điểm bắt đầu

// 5. Chờ DONE
uint32_t st;
do {
    st = mmio_read32(ed_reg, STATUS_REG);
} while ((st & STATUS_DONE) == 0);

unsigned long t_end = *mtime;  // Lấy thời điểm kết thúc

uint32_t elapsed32 = (uint32_t)(t_end - t_start);
kputs("\n\tPointMul elapsed time = ");
uart_put_dec((void*)uart_reg, elapsed32);
kputs(" us\r\n");


// 6. Đọc output
read_vec(ed_reg, QX_BASE, qx);
read_vec(ed_reg, QY_BASE, qy);

// 7. In kết quả
kprintf("\n\tQx =");
for (int i = 7; i >= 0; i--) {
    uart_put_hex((void*)uart_reg, qx[i]);
    // kputs("\r");
}

kputs("\r\n");
kprintf("\tQy =");
for (int i = 7; i >= 0; i--) {
    uart_put_hex((void*)uart_reg, qy[i]);
    // kputs("\r");
}

kputs("\r\n");
kprintf("\nTest done.\r\n");
  // If finished, stay in a infinite loop
  while(1);

  //dead code
  return 0;
}


