from azure.storage.common import CloudStorageAccount
from azure.storage.queue import Queue, QueueService, QueueMessage

queue_service = QueueService(connection_string="<your connection string>")


for i in range(1, 1000):
            messagename="test"
            queue_service.put_message("function", messagename + str(i))
            print ('Successfully added message: ', messagename + str(i))
