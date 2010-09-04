#ifndef RUN_TRACER_H_
#define RUN_TRACER_H_ 1

#define	TRACE_RECORD_MAGIC	0x0A0BABE0

typedef struct TRACE_RECORD_FILE_HEADER {
	UINT32		magic;
	UINT32		filesize;
	UINT32		addrsize;
	UINT32		num_records;
} TRACE_RECORD_FILE_HEADER;

enum TRACE_RECORD_TYPES {
	TRACE_TYPE_NONE = 0,        // invalid start point... we can reuse later
	TRACE_TYPE_INDIRECT_CALL,   // 1
	TRACE_TYPE_DIRECT_CALL,     // 2
	TRACE_TYPE_RETURN,          // 3
	TRACE_TYPE_BASIC_BLOCK,     // 4
	TRACE_TYPE_HEAP_ALLOC,      // 5
	TRACE_TYPE_HEAP_REALLOC,    // 6
	TRACE_TYPE_HEAP_FREE,       // 7
	TRACE_TYPE_MEMORY,          // 8
	TRACE_TYPE_LIBRAY_LOAD,     // 9
};

typedef struct TRACE_RECORD_HEADER {
	UINT32		type;
	THREADID	threadid;
} TRACE_RECORD_HEADER;

typedef struct TRACE_RECORD_CALL {
	ADDRINT		address;
	ADDRINT		target;
	ADDRINT		esp;
} TRACE_RECORD_CALL;

typedef struct TRACE_RECORD_RETURN {
	ADDRINT		address;
	ADDRINT		retval;
	ADDRINT		esp;
} TRACE_RECORD_RETURN;

typedef struct TRACE_RECORD_BASIC_BLOCK {
	ADDRINT		address;
} TRACE_RECORD_BASIC_BLOCK;

typedef struct TRACE_RECORD_HEAP_ALLOC {
	ADDRINT	heap;
	UINT64	size;
	ADDRINT	address;
} TRACE_RECORD_HEAP_ALLOC;

typedef struct TRACE_RECORD_HEAP_REALLOC {
	ADDRINT	heap;
	ADDRINT oldaddress;
	UINT64	size;
	ADDRINT	address;
} TRACE_RECORD_HEAP_REALLOC;

typedef struct TRACE_RECORD_HEAP_FREE {
	ADDRINT	heap;
	ADDRINT	address;
} TRACE_RECORD_HEAP_FREE;

typedef struct TRACE_RECORD_MEMORY {
	ADDRINT	address;
	UINT32	store;
	ADDRINT	target;
} TRACE_RECORD_MEMORY;

typedef struct TRACE_RECORD_LIBRARY_LOAD {
	ADDRINT	low;
	ADDRINT	high;
	UINT32	namelen;
	char	name[255];
};


typedef struct TRACE_RECORD {
	TRACE_RECORD_HEADER	header;
	union {
		TRACE_RECORD_CALL		call;
		TRACE_RECORD_RETURN		ret;
		TRACE_RECORD_BASIC_BLOCK	bbl;
		TRACE_RECORD_HEAP_ALLOC		alloc;
		TRACE_RECORD_HEAP_REALLOC	realloc;
		TRACE_RECORD_HEAP_FREE		free;
		TRACE_RECORD_MEMORY 		memory;
	};
} TRACE_RECORD;


#endif /* RUN_TRACER_H_ */
