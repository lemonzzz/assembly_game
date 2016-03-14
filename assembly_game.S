
.data					# section declaration

        # Useful offset constants for accessing members of a 
        # struct mp1_blink_struct structure
        LOCATION   = 0    
        ON_CHAR    = 2
        OFF_CHAR   = 3 
        ON_LENGTH  = 4
        OFF_LENGTH = 6
        COUNTDOWN  = 8
        STATUS     = 10
        NEXT       = 12
	
        STRUCT_SIZE = 16
		
		THREE 	   = 3
		FOUR_BYTE  = 4
		EIGHT_BYTE = 8
		TWELVE_BYTE = 12		
		SIXTEEN    =16
		OFFSET     =1999
# Pointer to head of list (initialized to NULL)
mp1_list_head:
        .long   0

.text					# section declaration

# Export the function symbol names

.global mp1_rtc_tasklet
.global mp1_ioctl



# void mp1_poke(void);
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX
mp1_poke:
        
	movl    vmem_base_addr(,1),%edx
	movb    %cl,(%edx,%eax,1)
	ret

# int mp1_helper(unsigned long loc);
#
# Interface: C-style arguments 
#    Inputs: EIGHT_BYTE(%ebp) - loc
#			 mp1_list_head
#
#   Outputs: %eax - the found pointer to location of the node, return 0 if not found
# Registers:  Clobbers EBX, ECX, EDX 

mp1_helper:														# set up the stack here, this function will use the input location to find a node in the linked list that has the same location
	pushl %ebp													
	movl %esp, %ebp
	pushl %ebx
	cmpl $0, mp1_list_head										# check if linked list is null, if yes, fail to find the node
	je helper_fail												
	movl mp1_list_head, %edx									
	jmp helper_start

helper_loop:													# traverse through each node of the linked list
	movl NEXT(%edx),%edx
helper_start:	
	movl EIGHT_BYTE(%ebp), %ebx     							
	movw %bx, %cx												
	cmpw %cx, LOCATION(%edx)									# match the pointer to newly allocated memory with node on linked list
	je helper_found
	cmpl $0, NEXT(%edx)
	jne helper_loop
	
helper_fail:													# if no node match the location, return 0, tear down stack and exit function
	movl $0, %eax
	jmp helper_finish
helper_found:
	movl %edx, %eax												# if found the corresponding node, return the found address into %eax, and tear down stack
helper_finish:													
	popl %ebx
	leave
	ret

	
# void mp1_rtc_tasklet(unsigned long) ;
#
# Interface: Register-based arguments (not C-style)
#    Inputs: mp1_list_head
#            
#   Outputs: make the fish blink between two status
# Registers:  Clobbers EBX, ECX, EDX 
		

mp1_rtc_tasklet:
	pushl %ebp													# set up the stack, this function will update the status of the game (change the display on screen)
	movl %esp, %ebp
	pushl %ebx
	cmpl $0, mp1_list_head										#check if the linked list is null, if so, tear down stack and exit the function
	je tasklet_finish											
	movl mp1_list_head, %edx
	jmp tasklet_linkedlist_start
	
tasklet_linkedlist_loop:									   # traverse linked list and change countdown and status values of each node			
	movl NEXT(%edx), %edx
tasklet_linkedlist_start:	
	subw $1, COUNTDOWN(%edx)
	cmpw $0, COUNTDOWN(%edx)
	jne tasklet_nostatus
    cmpw $0, STATUS(%edx)
	je tasklet_changetoon
	
tasklet_changetooff:										  # change the "on"(char) nodes to "off"
	pushl %eax
	pushl %ecx
	pushl %edx
	movl %edx, %ebx												
	movzwl LOCATION(%ebx), %eax
	shll $1, %eax
	movb OFF_CHAR(%ebx), %cl
	call mp1_poke											 # display the change on screen 
	popl %edx
	popl %ecx
	popl %eax
	jmp tasklet_updateoff
	
tasklet_changetoon:											 # change the "off"(char) nodes to "on"
	pushl %eax
	pushl %ecx
	pushl %edx
	movl %edx, %ebx											   
	movzwl LOCATION(%ebx), %eax
	shll $1, %eax											
	movb ON_CHAR(%ebx), %cl
	call mp1_poke											# display the change on screen 					 
	popl %edx
	popl %ecx
	popl %eax
tasklet_updateon:											
	movw ON_LENGTH(%edx), %cx
	movw %cx, COUNTDOWN(%edx)								# update the countdown of corresponding status, and update the status
	movw $1, STATUS(%edx)
	jmp tasklet_nostatus

tasklet_updateoff:
	movw OFF_LENGTH(%edx), %cx
	movw %cx, COUNTDOWN(%edx)	
	movw $0, STATUS(%edx)
	
tasklet_nostatus:											# check if we reach the end of linked list, if yes, end the function, otherwise traverse the linked list
	cmpl $0, NEXT(%edx)
	jne tasklet_linkedlist_loop
	
tasklet_finish:												# tear down stack
	popl %ebx
	leave
	ret

# int mp1_ioctl (unsigned long arg, unsigned long cmd);
# 
# Interface: C-style arguments
#	 Inputs: EIGHT_BYTE(%esp)	- store the parameter

#	Outputs: jump to different functions	
#
#	 Registers: Clobbers ECX
	
mp1_ioctl:													# this is the "dispatcher" function that use the number of cmd to decide which label to jump to 
	movl EIGHT_BYTE(%esp), %ecx   							
	cmpl $THREE, %ecx
	ja jump_table_fail										# check if the number cmd is out of bound of 0-3
	cmpl $0, %ecx
	jb jump_table_fail

	jmp *jump_table(, %ecx, 4)								# jump to corresponding function

jump_table:
	.long mp1_ioctl_add, mp1_ioctl_remove, mp1_ioctl_find, mp1_ioctl_sync

jump_table_fail:											
	ret														# return if the number cmd is out of bound

	
	
	
# int mp1_ioctl_add(unsigned long arg);
#
# Interface: C-style arguments
#    Inputs: EIGHT_BYTE(%ebp) - the arg
#
#   Outputs: add a node into linkedlist
# Registers: Clobbers EAX, EBX, ECX, EDX 

mp1_ioctl_add:
	pushl %ebp											  #set up the stack for add function, an ASCII picture of a fish should appear if this is working correctly
	movl %esp, %ebp
	pushl %ebx
	cmpl $0, EIGHT_BYTE(%ebp)		
	je add_fail
	
	pushl $STRUCT_SIZE
	call mp1_malloc   									  # make space in kernel to accept new data from user-level, and check to see if it succeed(not 0) in doing this
	addl $FOUR_BYTE, %esp
	cmpl $0, %eax
	je add_fail
	
	movl %eax, %ecx										  # copy the data we need from user-level buffer to kernel
	pushl %ecx
	pushl $STRUCT_SIZE
	pushl EIGHT_BYTE(%ebp)	                                
	pushl %eax 
	call mp1_copy_from_user                    			   
	movl %eax, %edx	                               		   
	addl $TWELVE_BYTE, %esp
	popl %ecx
	movl %ecx, %eax
	cmpl $0, %edx                             			 # if the byte that cannot be copied is not 0, means copy fail
	jne add_fail_malloc 

	
	movw ON_LENGTH(%eax), %bx                  			 # move the on-length into countdown 
	movw %bx, COUNTDOWN(%eax)
	
	movw $1, STATUS(%eax)
	
	movl mp1_list_head, %ebx          					 # add the new node into linked list          		  
	movl %ebx, NEXT(%eax)
	movl %eax, mp1_list_head
	
	pushl %edx
	movl %eax, %ebx
	cmpw $0, LOCATION(%ebx)								 # check if the location value is out of bound
	jb add_fail_malloc
	cmpw $OFFSET, LOCATION(%ebx)
	ja add_fail_malloc									 
	movzwl LOCATION(%ebx), %eax
	shll $1, %eax										# use mp1_poke to display the updated linked list on screen
	movb ON_CHAR(%ebx), %cl
	call mp1_poke										
	popl %edx
	
	movl $0, %eax       								# return 0 if the add succeed									                      			 
	jmp add_finish

add_fail_malloc:										# if the add fail after it allocated memory, return -1 and free the memory allocated
	pushl %eax
	call mp1_free
	addl $FOUR_BYTE, %esp
add_fail:												# if the add fail but no memory was allocated before it fail, return -1 
	movl $-1, %eax										
	
add_finish:
	popl %ebx											# tear down the stack of add function
	leave 
	ret
 
 
 
 
# int mp1_ioctl_remove(unsigned long arg);
#
# Interface: C-style arguments
#    Inputs: EIGHT_BYTE(%ebp) - the arg
#
#   Outputs: remove a node from linkedlist
# Registers: Clobbers EAX, ECX, EDX 
 
mp1_ioctl_remove:
	pushl %ebp										   # set up the stack for remove function, this function remove the specific node that has the same location with the input from the linked list 
	movl %esp, %ebp
	pushl %ebx
	
	pushl EIGHT_BYTE(%ebp)						       # find the node that we need to remove 
	call mp1_helper								
	addl $FOUR_BYTE, %esp
	cmpl $0, %eax									   # if the helper function return 0, means no node in linked list matches the location
	je remove_finish

remove_find_before:									   #  check if the node need to remove is the first one on linked list 
	cmpl mp1_list_head, %eax
	je remove_find_first
	
	movl mp1_list_head, %edx					
	jmp remove_find_start
	
remove_loop:										   # traverse through the linked list to find the node before the node that we need to remove
	movl NEXT(%edx),%edx
remove_find_start:
	cmpl NEXT(%edx), %eax
	je remove_found_before
	cmpl $0, NEXT(%edx)									# check if we reach the end of the linked list
	jne remove_loop
	
remove_find_first:										# the case when the node we need to remove is the head 
	movl NEXT(%eax), %ecx
	movl %ecx, mp1_list_head		
	jmp remove_pointer_finish
	
remove_found_before:									# the case when the node we need to remove is not the head
	movl NEXT(%eax), %ecx					   
	movl %ecx, NEXT(%edx)	
	
remove_pointer_finish:									# after remove, free the space malloced for the node
	pushl %eax 
	call mp1_free
	addl $FOUR_BYTE, %esp

remove_finish:											# tear down the stack of the remove function
	popl %ebx
	leave
	ret



# int mp1_ioctl_find(unsigned long arg);
#
# Interface: C-style arguments
#    Inputs: EIGHT_BYTE(%ebp) - the arg
#
#   Outputs: find a node in linkedlist and copy it out
# Registers: Clobbers EAX, EBX, ECX, EDX 	

mp1_ioctl_find:											# set up the stack for the find function, this function find a node on linked list and copy its information to a new node
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	
	cmpl $0, EIGHT_BYTE(%ebp)							# check to see the pointer passed in is not null
	je find_fail

	pushl $STRUCT_SIZE
	call mp1_malloc  									# make space in kernel to accept new data from user-level, and check to see if it succeed(not 0) in doing this
	addl $FOUR_BYTE, %esp
	cmpl $0, %eax										
	je find_fail
	
	movl %eax, %edx
	pushl %edx											# save caller saved register
	pushl $STRUCT_SIZE					
	pushl EIGHT_BYTE(%ebp)				 
	pushl %eax							
	call mp1_copy_from_user								#copy the data we need from user-level buffer to kernel
	movl %eax, %ebx
	#popl %eax							
	addl $TWELVE_BYTE, %esp
	popl %edx	
	movl %edx, %eax
	cmpl $0, %ebx										# if the function return something other than 0, means copy from user fail
	jne find_fail_malloc
				
	pushl %eax						 	 				# find the node we need on linked list
	movl (%eax), %ecx			
	pushl %ecx							  		
	call mp1_helper
	addl $FOUR_BYTE, %esp	
	movl %eax, %edx					 	 
	popl %eax						 	
	
	cmpl $0, %edx										# if we cannot find the node, free the memory we allocated on kernel before
	je find_fail_malloc			    					
	
	pushl %eax
	movl %edx, %ecx
	pushl %ecx
	pushl $STRUCT_SIZE					
	pushl %edx							
	pushl EIGHT_BYTE(%ebp)								
	call mp1_copy_to_user								# copy the data we need from kernel space buffer to user-level
	movl %eax, %ebx
	addl $TWELVE_BYTE, %esp
	popl %ecx
	movl %ecx, %edx
	popl %eax							
	cmpl $0, %ebx										# if return anything other than 0, means copy to user fail								
	jne find_fail_malloc
	jmp find_found	

find_fail_malloc:										# free the memory allocated if we fail to find the node and already malloced space
	pushl %eax
	call mp1_free
	addl $FOUR_BYTE, %esp
find_fail:
	movl $-1, %eax										# return -1 if we fail the find function
	jmp find_finish
find_found:
	pushl %eax
	call mp1_free
	addl $FOUR_BYTE, %esp
	movl $0, %eax										# return 0 if we use find function successfully
	
find_finish:											# tear down the stack for find function
	popl %ebx
	leave
	ret

	
	
	
# int mp1_ioctl_sync(unsigned long arg);
#
# Interface: C-style arguments
#    Inputs: EIGHT_BYTE(%ebp) - the arg
#
#   Outputs: sync the data of two nodes in a linkedlist
# Registers: Clobbers EAX, EBX, ECX	
	
mp1_ioctl_sync:											# set up the stack for sync function, this function should sync the "I","M" display change with the fish
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx	
	
	movl EIGHT_BYTE(%ebp), %eax 						
	
	movl $0, %ebx										# clear registers and let them represent upper and lower 16 bits of address
	movl $0, %ecx
	movw %ax, %bx			
	shrl $SIXTEEN, %eax		
	movw %ax, %cx			
	
	pushl %ecx
	pushl %ebx
	call mp1_helper										# find the node match the 2nd location passed in from linked list
	addl $FOUR_BYTE, %esp
	popl %ecx
	cmpl $0, %eax
	je sync_fail
	movl %eax, %ebx 									

	pushl %edx
	pushl %ecx
	call mp1_helper
	popl %ecx											# find the node match the 1st location passed in from linked list
	popl %edx
	cmpl $0, %eax
	je sync_fail	
	
	movw ON_LENGTH(%eax),%cx 							#sync the data in 2nd location with the data in 1st location
	movw %cx, ON_LENGTH(%ebx)
	movw OFF_LENGTH(%eax),%cx 	
	movw %cx, OFF_LENGTH(%ebx)
	movw COUNTDOWN(%eax),%cx 	
	movw %cx, COUNTDOWN(%ebx)
	movw STATUS(%eax),%cx 	
	movw %cx, STATUS(%ebx)
	
			
	movzwl LOCATION(%ebx), %eax 						# prepare to display the changed graphic on screen 
	shll $1, %eax										
	cmpw $0, STATUS(%ebx)
	je sync_offchar
sync_onchar:
	movb ON_CHAR(%ebx), %cl
	jmp sync_poke

sync_offchar:
	movb OFF_CHAR(%ebx), %cl							# decide whether to draw onchar or offchar, depend on status
	
sync_poke:
	call mp1_poke
	jmp sync_finish
		
sync_fail:
	movl $-1, %eax										# return -1 if sync fail
		
sync_finish:											#return 0 if sync succeed, and tear down the stack
	movl $0, %eax
	popl %ebx
	leave
	ret

.end